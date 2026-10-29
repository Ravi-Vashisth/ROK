import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';

class BackupService {
  static Map<String, dynamic> exportDatabaseToJson(Database db) {
    final Map<String, dynamic> backup = {};

    const tables = [
      'business_profile',
      'clients',
      'invoices',
      'invoice_items',
      'estimates',
      'estimate_items',
      'expenses',
      'payments',
      'saved_items'
    ];

    for (final table in tables) {
      try {
        final ResultSet result = db.select('SELECT * FROM $table');
        backup[table] = result.map((row) => Map<String, dynamic>.from(row)).toList();
      } catch (_) {
        backup[table] = [];
      }
    }

    backup['version'] = 1;
    backup['exported_at'] = DateTime.now().toIso8601String();
    return backup;
  }

  static void importDatabaseFromJson(Database db, Map<String, dynamic> backup) {
    db.execute('BEGIN TRANSACTION;');
    try {
      // Clear existing tables in correct FK order
      const tables = [
        'payments',
        'invoice_items',
        'estimate_items',
        'invoices',
        'estimates',
        'expenses',
        'saved_items',
        'clients',
        'business_profile'
      ];

      for (final table in tables) {
        try {
          db.execute('DELETE FROM $table;');
        } catch (_) {}
      }

      // Insert backup tables
      for (final table in tables) {
        final rows = backup[table] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          final keys = map.keys.toList();
          final placeholders = List.filled(keys.length, '?').join(', ');
          final columns = keys.join(', ');
          final values = keys.map((k) => map[k]).toList();

          final stmt = db.prepare('INSERT OR REPLACE INTO $table ($columns) VALUES ($placeholders)');
          try {
            stmt.execute(values);
          } finally {
            stmt.dispose();
          }
        }
      }

      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  static String exportToJsonString(Database db) {
    final map = exportDatabaseToJson(db);
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static void importFromJsonString(Database db, String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    importDatabaseFromJson(db, map);
  }
}
