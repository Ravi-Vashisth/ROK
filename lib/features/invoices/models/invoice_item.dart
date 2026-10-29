import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class InvoiceItem {
  final String id;
  final String invoiceId;
  final String description;
  final String sacHsn;
  final int quantity;
  final int unitPriceCents;
  final int taxRatePercentage;
  final int taxCents;
  final int totalCents;
  final String createdAt;

  const InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.description,
    this.sacHsn = '',
    required this.quantity,
    required this.unitPriceCents,
    this.taxRatePercentage = 0,
    this.taxCents = 0,
    required this.totalCents,
    required this.createdAt,
  });

  factory InvoiceItem.fromRow(sql.Row row) {
    return InvoiceItem(
      id: row['id'] as String,
      invoiceId: row['invoice_id'] as String,
      description: row['description'] as String,
      sacHsn: (row['sac_hsn'] as String?) ?? '',
      quantity: row['quantity'] as int,
      unitPriceCents: row['unit_price_cents'] as int,
      taxRatePercentage: (row['tax_rate_percentage'] as int?) ?? 0,
      taxCents: (row['tax_cents'] as int?) ?? 0,
      totalCents: row['total_cents'] as int,
      createdAt: row['created_at'] as String,
    );
  }
}
