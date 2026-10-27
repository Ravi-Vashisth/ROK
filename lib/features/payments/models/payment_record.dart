import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class PaymentRecord {
  final String id;
  final String invoiceId;
  final int amountCents;
  final String paymentMethod;
  final String paymentDate;
  final String notes;
  final String createdAt;

  const PaymentRecord({
    required this.id,
    required this.invoiceId,
    required this.amountCents,
    required this.paymentMethod,
    required this.paymentDate,
    required this.notes,
    required this.createdAt,
  });

  factory PaymentRecord.fromRow(sql.Row row) {
    return PaymentRecord(
      id: row['id'] as String,
      invoiceId: row['invoice_id'] as String,
      amountCents: row['amount_cents'] as int,
      paymentMethod: (row['payment_method'] as String?) ?? 'Cash',
      paymentDate: (row['payment_date'] as String?) ?? '',
      notes: (row['notes'] as String?) ?? '',
      createdAt: (row['created_at'] as String?) ?? '',
    );
  }
}
