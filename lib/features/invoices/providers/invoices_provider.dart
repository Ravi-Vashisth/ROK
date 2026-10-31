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
  final String sacHsn;
  final int unitPriceCents;
  final int quantity;
  final int taxRatePercentage;
  final int taxCents;
  final int totalCents;

  const DraftItem({
    required this.description,
    this.sacHsn = '',
    required this.unitPriceCents,
    required this.quantity,
    this.taxRatePercentage = 0,
    this.taxCents = 0,
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
        i.terms,
        i.notes,
        i.discount_type,
        i.discount_value,
        i.discount_cents,
        i.po_number,
        i.currency_code,
        i.currency_symbol,
        i.currency_decimals,
        i.created_at,
        COALESCE(SUM(CASE WHEN p.amount_received_cents > 0 OR p.tds_cents > 0 THEN p.amount_received_cents + p.tds_cents ELSE p.amount_cents END), 0) AS paid_cents
      FROM invoices i
      LEFT JOIN clients c ON i.client_id = c.id
      LEFT JOIN payments p ON i.id = p.invoice_id
      GROUP BY i.id
      ORDER BY i.created_at DESC
    ''');

    state = results.map((row) => InvoiceRecord.fromRow(row)).toList();
  }

  String getNextInvoiceNumber() {
    final profileRes = _db.select("SELECT invoice_prefix FROM business_profile WHERE id = 'default'");
    String prefix = 'INV-';
    if (profileRes.isNotEmpty) {
      prefix = (profileRes.first['invoice_prefix'] as String?) ?? 'INV-';
    }

    final offset = prefix.length + 1;
    final numRes = _db.select('''
      SELECT COALESCE(MAX(CAST(SUBSTR(invoice_number, ?) AS INTEGER)), 0) + 1 AS next_num FROM invoices;
    ''', [offset]);
    final nextNum = (numRes.first['next_num'] as int?) ?? 1;
    return '$prefix${nextNum.toString().padLeft(4, '0')}';
  }

  void voidInvoice(String invoiceId) {
    final stmt = _db.prepare("UPDATE invoices SET status = 'VOID' WHERE id = ?");
    try {
      stmt.execute([invoiceId]);
    } finally {
      stmt.dispose();
    }
    loadInvoices();
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
    String terms = '',
    String notes = '',
    String discountType = 'none',
    int discountValue = 0,
    String poNumber = '',
    String currencyCode = '',
    String currencySymbol = '',
    int currencyDecimals = 2,
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
    final discountCents = calculateDiscountCents(subtotalCents, discountType, discountValue);
    final netSubtotalCents = (subtotalCents - discountCents) > 0 ? (subtotalCents - discountCents) : 0;
    final itemsTaxSum = items.fold<int>(0, (sum, item) => sum + item.taxCents);
    final taxCents = itemsTaxSum > 0 ? itemsTaxSum : calculateTaxCents(netSubtotalCents, taxPercentage);
    final totalCents = netSubtotalCents + taxCents;

    _db.execute('BEGIN TRANSACTION;');
    try {
      final invoiceStmt = _db.prepare('''
        INSERT INTO invoices (
          id, client_id, invoice_number, subtotal_cents, tax_cents, total_cents,
          status, issue_date, due_date, payment_terms, terms, notes,
          discount_type, discount_value, discount_cents, po_number, currency_code, currency_symbol, currency_decimals, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
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
          terms,
          notes,
          discountType,
          discountValue,
          discountCents,
          poNumber,
          currencyCode,
          currencySymbol,
          currencyDecimals,
          createdAt,
        ]);
      } finally {
        invoiceStmt.dispose();
      }

      final itemStmt = _db.prepare('''
        INSERT INTO invoice_items (
          id, invoice_id, description, sac_hsn, quantity, unit_price_cents, tax_rate_percentage, tax_cents, total_cents, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        for (final item in items) {
          final itemId = generateUniqueId();
          itemStmt.execute([
            itemId,
            invoiceId,
            item.description,
            item.sacHsn,
            item.quantity,
            item.unitPriceCents,
            item.taxRatePercentage,
            item.taxCents,
            item.totalCents,
            createdAt,
          ]);
        }
      } finally {
        itemStmt.dispose();
      }

      // Increment next_invoice_number in business_profile
      _db.execute("UPDATE business_profile SET next_invoice_number = next_invoice_number + 1 WHERE id = 'default'");

      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }

    loadInvoices();
    return invoiceId;
  }

  /// Clones/Duplicates an existing invoice with today's date and a fresh sequential INV number.
  String duplicateInvoice(String sourceInvoiceId) {
    final invRes = _db.select('SELECT * FROM invoices WHERE id = ?', [sourceInvoiceId]);
    if (invRes.isEmpty) {
      throw ArgumentError('Source invoice not found.');
    }

    final sourceRow = invRes.first;
    final clientId = sourceRow['client_id'] as String;
    final paymentTerms = (sourceRow['payment_terms'] as String?) ?? 'Due on Receipt';
    final terms = (sourceRow['terms'] as String?) ?? '';
    final notes = (sourceRow['notes'] as String?) ?? '';
    final discountType = (sourceRow['discount_type'] as String?) ?? 'none';
    final discountValue = (sourceRow['discount_value'] as int?) ?? 0;
    final discountCents = (sourceRow['discount_cents'] as int?) ?? 0;
    final poNumber = (sourceRow['po_number'] as String?) ?? '';
    final currencyCode = (sourceRow['currency_code'] as String?) ?? '';
    final currencySymbol = (sourceRow['currency_symbol'] as String?) ?? '';
    final currencyDecimals = (sourceRow['currency_decimals'] as int?) ?? 2;
    final subtotalCents = sourceRow['subtotal_cents'] as int;
    final taxCents = sourceRow['tax_cents'] as int;
    final totalCents = sourceRow['total_cents'] as int;

    final sourceItems = getInvoiceItems(sourceInvoiceId);

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    int daysToAdd = 0;
    if (paymentTerms == 'Net 15 Days') daysToAdd = 15;
    if (paymentTerms == 'Net 30 Days') daysToAdd = 30;
    if (paymentTerms == 'Net 60 Days') daysToAdd = 60;
    final computedDue = now.add(Duration(days: daysToAdd));
    final dueDateStr =
        '${computedDue.year}-${computedDue.month.toString().padLeft(2, '0')}-${computedDue.day.toString().padLeft(2, '0')}';

    final newInvoiceId = generateUniqueId();
    final newInvoiceNumber = getNextInvoiceNumber();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    _db.execute('BEGIN TRANSACTION;');
    try {
      final invoiceStmt = _db.prepare('''
        INSERT INTO invoices (
          id, client_id, invoice_number, subtotal_cents, tax_cents, total_cents,
          status, issue_date, due_date, payment_terms, terms, notes,
          discount_type, discount_value, discount_cents, po_number, currency_code, currency_symbol, currency_decimals, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        invoiceStmt.execute([
          newInvoiceId,
          clientId,
          newInvoiceNumber,
          subtotalCents,
          taxCents,
          totalCents,
          'PENDING',
          todayStr,
          dueDateStr,
          paymentTerms,
          terms,
          notes,
          discountType,
          discountValue,
          discountCents,
          poNumber,
          currencyCode,
          currencySymbol,
          currencyDecimals,
          createdAt,
        ]);
      } finally {
        invoiceStmt.dispose();
      }

      final itemStmt = _db.prepare('''
        INSERT INTO invoice_items (
          id, invoice_id, description, sac_hsn, quantity, unit_price_cents, total_cents, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        for (final item in sourceItems) {
          final newItemId = generateUniqueId();
          itemStmt.execute([
            newItemId,
            newInvoiceId,
            item.description,
            item.sacHsn,
            item.quantity,
            item.unitPriceCents,
            item.totalCents,
            createdAt,
          ]);
        }
      } finally {
        itemStmt.dispose();
      }

      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }

    loadInvoices();
    return newInvoiceNumber;
  }

  /// Records a partial or full payment installment against an invoice.
  void recordPayment({
    required String invoiceId,
    required int amountCents,
    int amountReceivedCents = 0,
    int tdsCents = 0,
    String referenceNumber = '',
    required String paymentMethod,
    required DateTime paymentDate,
    String notes = '',
  }) {
    final effectiveReceived = (amountReceivedCents == 0 && tdsCents == 0) ? amountCents : amountReceivedCents;
    final totalCreditCents = effectiveReceived + tdsCents;

    if (totalCreditCents <= 0) {
      throw ArgumentError('Total payment credit must be greater than zero.');
    }

    final paymentId = generateUniqueId();
    final paymentDateStr =
        '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}';
    final createdAt = DateTime.now().toUtc().toIso8601String();

    _db.execute('BEGIN TRANSACTION;');
    try {
      final stmt = _db.prepare('''
        INSERT INTO payments (
          id, invoice_id, amount_cents, amount_received_cents, tds_cents, reference_number, payment_method, payment_date, notes, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        stmt.execute([
          paymentId,
          invoiceId,
          totalCreditCents,
          effectiveReceived,
          tdsCents,
          referenceNumber,
          paymentMethod,
          paymentDateStr,
          notes,
          createdAt,
        ]);
      } finally {
        stmt.dispose();
      }

      final paidRes = _db.select(
        'SELECT COALESCE(SUM(CASE WHEN amount_received_cents > 0 OR tds_cents > 0 THEN amount_received_cents + tds_cents ELSE amount_cents END), 0) AS total_paid FROM payments WHERE invoice_id = ?',
        [invoiceId],
      );
      final totalPaid = (paidRes.first['total_paid'] as int?) ?? 0;

      final invRes = _db.select(
        'SELECT total_cents, status FROM invoices WHERE id = ?',
        [invoiceId],
      );
      if (invRes.isNotEmpty) {
        final totalCents = invRes.first['total_cents'] as int;
        final currentStatus = (invRes.first['status'] as String?) ?? 'PENDING';
        if (currentStatus != 'VOID') {
          final newStatus = totalPaid >= totalCents ? 'PAID' : (totalPaid > 0 ? 'PARTIALLY_PAID' : 'PENDING');
          final updateStmt = _db.prepare('UPDATE invoices SET status = ? WHERE id = ?');
          try {
            updateStmt.execute([newStatus, invoiceId]);
          } finally {
            updateStmt.dispose();
          }
        }
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
    try {
      stmt.execute([newStatus, invoiceId]);
    } finally {
      stmt.dispose();
    }
    loadInvoices();
  }
}

final invoicesProvider = StateNotifierProvider<InvoicesNotifier, List<InvoiceRecord>>((ref) {
  return InvoicesNotifier(ref.watch(databaseProvider));
});
