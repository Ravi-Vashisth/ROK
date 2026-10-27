import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money_utils.dart';
import '../../payments/models/payment_record.dart';
import '../models/invoice_item.dart';
import '../models/invoice_record.dart';

/// Lightweight representation of an in-memory draft line item before committing to SQLite.
class DraftItem {
  final String description;
  final int unitPriceCents;
  final int quantity;
  final int totalCents;

  const DraftItem({
    required this.description,
    required this.unitPriceCents,
    required this.quantity,
    required this.totalCents,
  });
}

class InvoicesNotifier extends StateNotifier<List<InvoiceRecord>> {
  final Database _db;

  InvoicesNotifier(this._db) : super([]) {
    loadInvoices();
  }

  void loadInvoices() {
    final ResultSet results = _db.select('''
      SELECT 
        i.id,
        i.client_id,
        c.name AS client_name,
        i.invoice_number,
        i.subtotal_cents,
        i.tax_cents,
        i.total_cents,
        i.status,
        i.issue_date,
        i.due_date,
        i.payment_terms,
        i.created_at,
        COALESCE(SUM(p.amount_cents), 0) AS paid_cents
      FROM invoices i
      LEFT JOIN clients c ON i.client_id = c.id
      LEFT JOIN payments p ON i.id = p.invoice_id
      GROUP BY i.id
      ORDER BY i.created_at DESC
    ''');

    state = results.map((row) => InvoiceRecord.fromRow(row)).toList();
  }

  String getNextInvoiceNumber() {
    final result = _db.select('SELECT COUNT(*) AS total FROM invoices');
    final count = (result.first['total'] as int?) ?? 0;
    final nextNumber = count + 1;
    return 'INV-${nextNumber.toString().padLeft(4, '0')}';
  }

  /// Fetches all line items associated with a specific invoice.
  List<InvoiceItem> getInvoiceItems(String invoiceId) {
    final ResultSet results = _db.select(
      'SELECT * FROM invoice_items WHERE invoice_id = ? ORDER BY rowid ASC',
      [invoiceId],
    );
    return results.map((row) => InvoiceItem.fromRow(row)).toList();
  }

  /// Fetches all payments associated with a specific invoice.
  List<PaymentRecord> getInvoicePayments(String invoiceId) {
    final ResultSet results = _db.select(
      'SELECT * FROM payments WHERE invoice_id = ? ORDER BY payment_date DESC, created_at DESC',
      [invoiceId],
    );
    return results.map((row) => PaymentRecord.fromRow(row)).toList();
  }

  /// Commits an invoice and all its line items within an atomic SQLite transaction.
  String saveInvoice({
    required String clientId,
    required List<DraftItem> items,
    required int taxPercentage,
    String paymentTerms = 'Due on Receipt',
    String? issueDate,
    String? dueDate,
    String status = 'PENDING',
  }) {
    if (items.isEmpty) {
      throw ArgumentError('Cannot save an invoice with no line items.');
    }

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final effectiveIssueDate = (issueDate != null && issueDate.trim().isNotEmpty)
        ? issueDate.trim()
        : todayStr;

    String effectiveDueDate = (dueDate != null && dueDate.trim().isNotEmpty)
        ? dueDate.trim()
        : effectiveIssueDate;

    if (dueDate == null || dueDate.trim().isEmpty) {
      try {
        final parsedIssue = DateTime.parse(effectiveIssueDate);
        int daysToAdd = 0;
        if (paymentTerms == 'Net 15 Days') daysToAdd = 15;
        if (paymentTerms == 'Net 30 Days') daysToAdd = 30;
        if (paymentTerms == 'Net 60 Days') daysToAdd = 60;
        final computedDue = parsedIssue.add(Duration(days: daysToAdd));
        effectiveDueDate =
            '${computedDue.year}-${computedDue.month.toString().padLeft(2, '0')}-${computedDue.day.toString().padLeft(2, '0')}';
      } catch (_) {
        effectiveDueDate = effectiveIssueDate;
      }
    }

    final invoiceId = generateUniqueId();
    final invoiceNumber = getNextInvoiceNumber();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final subtotalCents = items.fold<int>(0, (sum, item) => sum + item.totalCents);
    final taxCents = calculateTaxCents(subtotalCents, taxPercentage);
    final totalCents = subtotalCents + taxCents;

    _db.execute('BEGIN TRANSACTION;');
    try {
      final invoiceStmt = _db.prepare('''
        INSERT INTO invoices (
          id, client_id, invoice_number, subtotal_cents, tax_cents, total_cents,
          status, issue_date, due_date, payment_terms, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      invoiceStmt.execute([
        invoiceId,
        clientId,
        invoiceNumber,
        subtotalCents,
        taxCents,
        totalCents,
        status,
        effectiveIssueDate,
        effectiveDueDate,
        paymentTerms,
        createdAt,
      ]);
      invoiceStmt.dispose();

      final itemStmt = _db.prepare('''
        INSERT INTO invoice_items (
          id, invoice_id, description, quantity, unit_price_cents, total_cents, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''');
      for (final item in items) {
        final itemId = generateUniqueId();
        itemStmt.execute([
          itemId,
          invoiceId,
          item.description,
          item.quantity,
          item.unitPriceCents,
          item.totalCents,
          createdAt,
        ]);
      }
      itemStmt.dispose();

      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }

    loadInvoices();
    return invoiceId;
  }

  /// Records a partial or full payment installment against an invoice.
  void recordPayment({
    required String invoiceId,
    required int amountCents,
    required String paymentMethod,
    required DateTime paymentDate,
    String notes = '',
  }) {
    if (amountCents <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final paymentId = generateUniqueId();
    final paymentDateStr =
        '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}';
    final createdAt = DateTime.now().toUtc().toIso8601String();

    _db.execute('BEGIN TRANSACTION;');
    try {
      final stmt = _db.prepare('''
        INSERT INTO payments (
          id, invoice_id, amount_cents, payment_method, payment_date, notes, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''');
      stmt.execute([
        paymentId,
        invoiceId,
        amountCents,
        paymentMethod,
        paymentDateStr,
        notes,
        createdAt,
      ]);
      stmt.dispose();

      final paidRes = _db.select(
        'SELECT COALESCE(SUM(amount_cents), 0) AS total_paid FROM payments WHERE invoice_id = ?',
        [invoiceId],
      );
      final totalPaid = (paidRes.first['total_paid'] as int?) ?? 0;

      final invRes = _db.select(
        'SELECT total_cents FROM invoices WHERE id = ?',
        [invoiceId],
      );
      if (invRes.isNotEmpty) {
        final totalCents = invRes.first['total_cents'] as int;
        final newStatus = totalPaid >= totalCents ? 'PAID' : (totalPaid > 0 ? 'PARTIALLY_PAID' : 'PENDING');
        final updateStmt = _db.prepare('UPDATE invoices SET status = ? WHERE id = ?');
        updateStmt.execute([newStatus, invoiceId]);
        updateStmt.dispose();
      }

      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }

    loadInvoices();
  }

  void updateInvoiceStatus(String invoiceId, String newStatus) {
    final stmt = _db.prepare('UPDATE invoices SET status = ? WHERE id = ?');
    stmt.execute([newStatus, invoiceId]);
    stmt.dispose();
    loadInvoices();
  }
}

final invoicesProvider = StateNotifierProvider<InvoicesNotifier, List<InvoiceRecord>>((ref) {
  return InvoicesNotifier(ref.watch(databaseProvider));
});
