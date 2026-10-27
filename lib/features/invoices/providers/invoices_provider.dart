import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/id_generator.dart';
import '../models/invoice_record.dart';

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

  void saveInvoice({
    required String clientId,
    required int subtotalCents,
    required int taxCents,
    required int totalCents,
  }) {
    final id = generateUniqueId();
    final invoiceNumber = getNextInvoiceNumber();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    const status = 'PAID';

    final stmt = _db.prepare('''
      INSERT INTO invoices (
        id, client_id, invoice_number, subtotal_cents, tax_cents, total_cents, status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');

    stmt.execute([
      id,
      clientId,
      invoiceNumber,
      subtotalCents,
      taxCents,
      totalCents,
      status,
      createdAt,
    ]);
    stmt.dispose();

    loadInvoices();
  }
}

final invoicesProvider = StateNotifierProvider<InvoicesNotifier, List<InvoiceRecord>>((ref) {
  return InvoicesNotifier(ref.watch(databaseProvider));
});
