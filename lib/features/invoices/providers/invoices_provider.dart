import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money_utils.dart';
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
        i.created_at
      FROM invoices i
      LEFT JOIN clients c ON i.client_id = c.id
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

  /// Commits an invoice and all its line items within an atomic SQLite transaction.
  void saveInvoice({
    required String clientId,
    required List<DraftItem> items,
    required int taxPercentage,
  }) {
    if (items.isEmpty) {
      throw ArgumentError('Cannot save an invoice with no line items.');
    }

    final invoiceId = generateUniqueId();
    final invoiceNumber = getNextInvoiceNumber();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    const status = 'PAID';

    final subtotalCents = items.fold<int>(0, (sum, item) => sum + item.totalCents);
    final taxCents = calculateTaxCents(subtotalCents, taxPercentage);
    final totalCents = subtotalCents + taxCents;

    // Atomic SQLite Transaction
    _db.execute('BEGIN TRANSACTION;');
    try {
      // 1. Insert master invoice record
      final invoiceStmt = _db.prepare('''
        INSERT INTO invoices (
          id, client_id, invoice_number, subtotal_cents, tax_cents, total_cents, status, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      invoiceStmt.execute([
        invoiceId,
        clientId,
        invoiceNumber,
        subtotalCents,
        taxCents,
        totalCents,
        status,
        createdAt,
      ]);
      invoiceStmt.dispose();

      // 2. Insert line items
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
  }
}

final invoicesProvider = StateNotifierProvider<InvoicesNotifier, List<InvoiceRecord>>((ref) {
  return InvoicesNotifier(ref.watch(databaseProvider));
});
