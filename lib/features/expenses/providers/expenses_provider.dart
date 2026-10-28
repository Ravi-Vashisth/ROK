import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/id_generator.dart';
import '../models/expense_record.dart';

class ExpensesNotifier extends StateNotifier<List<ExpenseRecord>> {
  final Database _db;

  ExpensesNotifier(this._db) : super([]) {
    loadExpenses();
  }

  void loadExpenses() {
    final ResultSet results = _db.select('SELECT * FROM expenses ORDER BY expense_date DESC, created_at DESC');
    state = results.map((row) => ExpenseRecord.fromRow(row)).toList();
  }

  void addExpense({
    required String category,
    required String vendor,
    required int amountCents,
    int taxCents = 0,
    required String expenseDate,
    String notes = '',
  }) {
    final id = generateUniqueId();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final stmt = _db.prepare('''
      INSERT INTO expenses (id, category, vendor, amount_cents, tax_cents, expense_date, notes, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute([id, category, vendor, amountCents, taxCents, expenseDate, notes, createdAt]);
    } finally {
      stmt.dispose();
    }
    loadExpenses();
  }

  void deleteExpense(String id) {
    final stmt = _db.prepare('DELETE FROM expenses WHERE id = ?');
    try {
      stmt.execute([id]);
    } finally {
      stmt.dispose();
    }
    loadExpenses();
  }
}

final expensesProvider = StateNotifierProvider<ExpensesNotifier, List<ExpenseRecord>>((ref) {
  return ExpensesNotifier(ref.watch(databaseProvider));
});
