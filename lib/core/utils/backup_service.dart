import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';

class BackupService {
  /// Exports all database tables to a clean JSON string with version and timestamp.
  static String exportDatabaseToJson(Database db) {
    final tables = [
      'clients',
      'invoices',
      'invoice_items',
      'payments',
      'estimates',
      'estimate_items',
      'saved_items',
      'business_profile',
    ];

    final Map<String, List<Map<String, dynamic>>> data = {};
    for (final table in tables) {
      try {
        final ResultSet result = db.select('SELECT * FROM $table');
        data[table] = result.map((row) => Map<String, dynamic>.from(row)).toList();
      } catch (_) {
        data[table] = [];
      }
    }

    final backupPayload = {
      'version': 1,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'tables': data,
    };

    return jsonEncode(backupPayload);
  }

  /// Imports database state from JSON string, wrapping in an atomic SQLite transaction.
  static void importDatabaseFromJson(Database db, String jsonContent) {
    final Map<String, dynamic> parsed = jsonDecode(jsonContent);
    final tablesData = parsed['tables'] as Map<String, dynamic>?;
    if (tablesData == null) {
      throw FormatException('Invalid backup JSON format: missing "tables" key.');
    }

    db.execute('BEGIN TRANSACTION;');
    try {
      db.execute('PRAGMA foreign_keys = OFF;');

      final deleteOrder = [
        'estimate_items',
        'estimates',
        'invoice_items',
        'payments',
        'invoices',
        'clients',
        'saved_items',
        'business_profile',
      ];

      for (final table in deleteOrder) {
        try {
          db.execute('DELETE FROM $table;');
        } catch (_) {}
      }

      for (final entry in tablesData.entries) {
        final table = entry.key;
        final rows = entry.value as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        for (final rowObj in rows) {
          final row = Map<String, dynamic>.from(rowObj as Map);
          if (row.isEmpty) continue;

          final keys = row.keys.toList();
          final placeholders = List.filled(keys.length, '?').join(', ');
          final columns = keys.join(', ');
          final values = keys.map((k) => row[k]).toList();

          final stmt = db.prepare('INSERT OR REPLACE INTO $table ($columns) VALUES ($placeholders)');
          try {
            stmt.execute(values);
          } finally {
            stmt.dispose();
          }
        }
      }

      db.execute('PRAGMA foreign_keys = ON;');
      db.execute('COMMIT;');
    } catch (e) {
      db.execute('PRAGMA foreign_keys = ON;');
      db.execute('ROLLBACK;');
      rethrow;
    }
  }
}
