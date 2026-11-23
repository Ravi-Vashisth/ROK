import 'package:sqlite3/sqlite3.dart' as sql show Row;

class ExpenseRecord {
  final String id;
  final String category;
  final String vendor;
  final int amountCents;
  final int taxCents;
  final String expenseDate;
  final String notes;
  final String receiptBase64;
  final String receiptName;
  final String currencyCode;
  final int currencyDecimals;
  final String createdAt;

  const ExpenseRecord({
    required this.id,
    required this.category,
    required this.vendor,
    required this.amountCents,
    this.taxCents = 0,
    required this.expenseDate,
    this.notes = '',
    this.receiptBase64 = '',
    this.receiptName = '',
    this.currencyCode = '',
    this.currencyDecimals = 2,
    required this.createdAt,
  });

  factory ExpenseRecord.fromRow(sql.Row row) {
    final code = (row['currency_code'] as String?) ?? '';
    return ExpenseRecord(
      id: row['id'] as String,
      category: (row['category'] as String?) ?? 'Other',
      vendor: (row['vendor'] as String?) ?? '',
      amountCents: (row['amount_cents'] as int?) ?? 0,
      taxCents: (row['tax_cents'] as int?) ?? 0,
      expenseDate: (row['expense_date'] as String?) ?? '',
      notes: (row['notes'] as String?) ?? '',
      receiptBase64: (row['receipt_base64'] as String?) ?? '',
      receiptName: (row['receipt_name'] as String?) ?? '',
      currencyCode: code,
      currencyDecimals: (row['currency_decimals'] as int?) ?? 2,
      createdAt: (row['created_at'] as String?) ?? '',
    );
  }

  int get totalCents => amountCents + taxCents;
  bool get hasReceipt => receiptBase64.isNotEmpty;
}
