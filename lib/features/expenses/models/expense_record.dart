import 'package:sqlite3/sqlite3.dart' as sql show Row;

class ExpenseRecord {
  final String id;
  final String category;
  final String vendor;
  final int amountCents;
  final int taxCents;
  final String expenseDate;
  final String notes;
  final String createdAt;

  const ExpenseRecord({
    required this.id,
    required this.category,
    required this.vendor,
    required this.amountCents,
    this.taxCents = 0,
    required this.expenseDate,
    this.notes = '',
    required this.createdAt,
  });

  factory ExpenseRecord.fromRow(sql.Row row) {
    return ExpenseRecord(
      id: row['id'] as String,
      category: (row['category'] as String?) ?? 'Other',
      vendor: (row['vendor'] as String?) ?? '',
      amountCents: (row['amount_cents'] as int?) ?? 0,
      taxCents: (row['tax_cents'] as int?) ?? 0,
      expenseDate: (row['expense_date'] as String?) ?? '',
      notes: (row['notes'] as String?) ?? '',
      createdAt: (row['created_at'] as String?) ?? '',
    );
  }

  int get totalCents => amountCents + taxCents;
}
