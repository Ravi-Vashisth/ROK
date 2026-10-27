import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class InvoiceRecord {
  final String id;
  final String clientId;
  final String clientName;
  final String invoiceNumber;
  final int subtotalCents;
  final int taxCents;
  final int totalCents;
  final String status;
  final String createdAt;

  const InvoiceRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.invoiceNumber,
    required this.subtotalCents,
    required this.taxCents,
    required this.totalCents,
    required this.status,
    required this.createdAt,
  });

  factory InvoiceRecord.fromRow(sql.Row row) {
    return InvoiceRecord(
      id: row['id'] as String,
      clientId: row['client_id'] as String,
      clientName: (row['client_name'] as String?) ?? 'Unknown Client',
      invoiceNumber: row['invoice_number'] as String,
      subtotalCents: row['subtotal_cents'] as int,
      taxCents: row['tax_cents'] as int,
      totalCents: row['total_cents'] as int,
      status: row['status'] as String,
      createdAt: row['created_at'] as String,
    );
  }
}
