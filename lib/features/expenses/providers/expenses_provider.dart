import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:billing_app/core/database/database_provider.dart';
import 'package:billing_app/core/utils/id_generator.dart';
import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/features/expenses/models/expense_record.dart';

class ExpensesNotifier extends StateNotifier<List<ExpenseRecord>> {
  final Database _db;

  ExpensesNotifier(this._db) : super([]) {
    loadExpenses();
  }

  ({String code, int decimals}) _readProfileCurrency() {
    final rows = _db.select(
      "SELECT currency_code, currency_decimals FROM business_profile WHERE id = 'default' LIMIT 1",
    );
    if (rows.isEmpty) {
      return (code: 'USD', decimals: 2);
    }
    final rawCode = (rows.first['currency_code'] as String?)?.trim().toUpperCase() ?? '';
    final code = rawCode.isNotEmpty ? rawCode : 'USD';
    final rawDec = rows.first['currency_decimals'] as int?;
    final decimals = rawDec ?? getCurrencyDecimals(code);
    return (code: code, decimals: decimals);
  }

  void loadExpenses() {
    final ResultSet results = _db.select(
      'SELECT * FROM expenses WHERE deleted_at IS NULL ORDER BY expense_date DESC, created_at DESC',
    );
    state = results.map((row) => ExpenseRecord.fromRow(row)).toList();
  }

  void addExpense({
    required String category,
    required String vendor,
    required int amountCents,
    int taxCents = 0,
    required String expenseDate,
    String notes = '',
    String receiptBase64 = '',
    String receiptName = '',
    String? currencyCode,
    int? currencyDecimals,
  }) {
    final id = generateUniqueId();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final profileCur = _readProfileCurrency();
    final resolvedCode =
        (currencyCode != null && currencyCode.trim().isNotEmpty)
            ? currencyCode.trim().toUpperCase()
            : profileCur.code;
    final resolvedDecimals = currencyDecimals ??
        (currencyCode != null && currencyCode.trim().isNotEmpty
            ? getCurrencyDecimals(resolvedCode)
            : profileCur.decimals);

    final stmt = _db.prepare('''
      INSERT INTO expenses (id, category, vendor, amount_cents, tax_cents, expense_date, notes, receipt_base64, receipt_name, currency_code, currency_decimals, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute([
        id,
        category,
        vendor,
        amountCents,
        taxCents,
        expenseDate,
        notes,
        receiptBase64,
        receiptName,
        resolvedCode,
        resolvedDecimals,
        nowIso,
        nowIso,
      ]);
    } finally {
      stmt.dispose();
    }
    loadExpenses();
  }

  void updateExpense({
    required String id,
    required String category,
    required String vendor,
    required int amountCents,
    int taxCents = 0,
    required String expenseDate,
    String notes = '',
    String receiptBase64 = '',
    String receiptName = '',
    String? currencyCode,
    int? currencyDecimals,
  }) {
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    final existing = _db.select(
      'SELECT currency_code, currency_decimals FROM expenses WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [id],
    );
    final existingCode = existing.isNotEmpty
        ? ((existing.first['currency_code'] as String?)?.trim().toUpperCase() ?? '')
        : '';
    final existingDec = existing.isNotEmpty
        ? (existing.first['currency_decimals'] as int?)
        : null;

    final hasExplicitCode = currencyCode != null && currencyCode.trim().isNotEmpty;
    final resolvedCode =
        hasExplicitCode ? currencyCode.trim().toUpperCase() : existingCode;
    final resolvedDecimals = hasExplicitCode
        ? (currencyDecimals ?? getCurrencyDecimals(resolvedCode))
        : (currencyDecimals ?? existingDec ?? 2);

    final stmt = _db.prepare('''
      UPDATE expenses
      SET category = ?, vendor = ?, amount_cents = ?, tax_cents = ?, expense_date = ?, notes = ?, receipt_base64 = ?, receipt_name = ?, currency_code = ?, currency_decimals = ?, updated_at = ?
      WHERE id = ? AND deleted_at IS NULL
    ''');
    try {
      stmt.execute([
        category,
        vendor,
        amountCents,
        taxCents,
        expenseDate,
        notes,
        receiptBase64,
        receiptName,
        resolvedCode,
        resolvedDecimals,
        updatedAt,
        id,
      ]);
    } finally {
      stmt.dispose();
    }
    loadExpenses();
  }

  void deleteExpense(String id) {
    final deletedAt = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN TRANSACTION;');
    try {
      final stmt = _db.prepare(
        'UPDATE expenses SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL',
      );
      try {
        stmt.execute([deletedAt, deletedAt, id]);
      } finally {
        stmt.dispose();
      }
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
    loadExpenses();
  }
}

final expensesProvider = StateNotifierProvider<ExpensesNotifier, List<ExpenseRecord>>((ref) {
  return ExpensesNotifier(ref.watch(databaseProvider));
});
