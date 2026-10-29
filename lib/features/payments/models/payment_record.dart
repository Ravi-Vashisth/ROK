import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class PaymentRecord {
  final String id;
  final String invoiceId;
  final int amountCents;
  final int amountReceivedCents;
  final int tdsCents;
  final String referenceNumber;
  final String paymentMethod;
  final String paymentDate;
  final String notes;
  final String createdAt;

  const PaymentRecord({
    required this.id,
    required this.invoiceId,
    required this.amountCents,
    this.amountReceivedCents = 0,
    this.tdsCents = 0,
    this.referenceNumber = '',
    required this.paymentMethod,
    required this.paymentDate,
    required this.notes,
    required this.createdAt,
  });

  int get totalCreditCents =>
      (amountReceivedCents > 0 || tdsCents > 0) ? (amountReceivedCents + tdsCents) : amountCents;

  factory PaymentRecord.fromRow(sql.Row row) {
    final rawAmount = row['amount_cents'] as int;
    final rawReceived = (row['amount_received_cents'] as int?) ?? 0;
    final rawTds = (row['tds_cents'] as int?) ?? 0;
    final effectiveReceived = (rawReceived == 0 && rawTds == 0) ? rawAmount : rawReceived;

    return PaymentRecord(
      id: row['id'] as String,
      invoiceId: row['invoice_id'] as String,
      amountCents: rawAmount,
      amountReceivedCents: effectiveReceived,
      tdsCents: rawTds,
      referenceNumber: (row['reference_number'] as String?) ?? '',
      paymentMethod: (row['payment_method'] as String?) ?? 'Bank Wire',
      paymentDate: (row['payment_date'] as String?) ?? '',
      notes: (row['notes'] as String?) ?? '',
      createdAt: (row['created_at'] as String?) ?? '',
    );
  }
}
