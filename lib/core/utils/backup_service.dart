import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';

class BackupService {
  static const Map<String, Set<String>> allowedTableColumns = {
    'business_profile': {
      'id',
      'business_name',
      'email',
      'phone',
      'address',
      'tax_id',
      'payment_details',
      'currency_symbol',
      'currency_code',
      'currency_decimals',
      'default_terms',
      'default_notes',
      'logo_base64',
      'signature_base64',
      'signature_label',
      'invoice_prefix',
      'estimate_prefix',
      'next_invoice_number',
      'payment_qr_payload',
      'default_tax_mode',
      'default_pst_rate_percentage',
    },
    'clients': {
      'id',
      'name',
      'email',
      'phone',
      'address',
      'tax_id',
      'created_at',
    },
    'invoices': {
      'id',
      'client_id',
      'invoice_number',
      'subtotal_cents',
      'tax_cents',
      'total_cents',
      'status',
      'issue_date',
      'due_date',
      'payment_terms',
      'terms',
      'notes',
      'discount_type',
      'discount_value',
      'discount_cents',
      'po_number',
      'currency_code',
      'currency_symbol',
      'currency_decimals',
      'tax_mode',
      'pst_rate_percentage',
      'tax_exemption_id',
      'created_at',
    },
    'invoice_items': {
      'id',
      'invoice_id',
      'description',
      'sac_hsn',
      'quantity',
      'unit_price_cents',
      'tax_rate_percentage',
      'tax_cents',
      'total_cents',
      'created_at',
    },
    'estimates': {
      'id',
      'client_id',
      'estimate_number',
      'subtotal_cents',
      'tax_cents',
      'total_cents',
      'status',
      'issue_date',
      'expiry_date',
      'converted_invoice_id',
      'terms',
      'notes',
      'discount_type',
      'discount_value',
      'discount_cents',
      'po_number',
      'currency_code',
      'currency_symbol',
      'currency_decimals',
      'tax_mode',
      'pst_rate_percentage',
      'tax_exemption_id',
      'created_at',
    },
    'estimate_items': {
      'id',
      'estimate_id',
      'description',
      'sac_hsn',
      'quantity',
      'unit_price_cents',
      'tax_rate_percentage',
      'tax_cents',
      'total_cents',
      'created_at',
    },
    'expenses': {
      'id',
      'category',
      'vendor',
      'amount_cents',
      'tax_cents',
      'expense_date',
      'notes',
      'receipt_base64',
      'receipt_name',
      'created_at',
    },
    'saved_items': {
      'id',
      'title',
      'sac_hsn',
      'default_price_cents',
      'description',
      'created_at',
    },
    'payments': {
      'id',
      'invoice_id',
      'amount_cents',
      'amount_received_cents',
      'tds_cents',
      'reference_number',
      'payment_method',
      'payment_date',
      'notes',
      'created_at',
    },
  };

  /// Filters an untrusted row map to ONLY schema-allowlisted columns for [table].
  /// Throws [ArgumentError] if [table] is not in the allowlist.
  static Map<String, dynamic> sanitizeRowForTable(
    String table,
    Map<dynamic, dynamic> rawRow,
  ) {
    final allowed = allowedTableColumns[table];
    if (allowed == null) {
      throw ArgumentError('Unsupported backup table: $table');
    }
    final sanitized = <String, dynamic>{};
    for (final entry in rawRow.entries) {
      final key = entry.key?.toString() ?? '';
      if (allowed.contains(key)) {
        sanitized[key] = entry.value;
      }
    }
    return sanitized;
  }

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

  static void validateBackupMap(Map<String, dynamic> backup) {
    if (!backup.containsKey('business_profile') ||
        !backup.containsKey('clients') ||
        !backup.containsKey('invoices')) {
      throw const FormatException(
          'Invalid backup file: The selected file is not a valid Freelance Ledger database snapshot.');
    }

    for (final table in allowedTableColumns.keys) {
      if (!backup.containsKey(table)) continue;
      final value = backup[table];
      if (value is! List) {
        throw FormatException(
            'Invalid backup file: Table "$table" must be a JSON array.');
      }
      for (final item in value) {
        if (item is! Map) {
          throw FormatException(
              'Invalid backup file: Records in "$table" must be JSON objects.');
        }
      }
    }
  }

  static void importDatabaseFromJson(Database db, Map<String, dynamic> backup) {
    validateBackupMap(backup);

    db.execute('BEGIN TRANSACTION;');
    try {
      // Clear existing tables in correct child-first FK order
      const clearTables = [
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

      for (final table in clearTables) {
        db.execute('DELETE FROM $table;');
      }

      // Insert backup tables in PARENT-FIRST dependency order using strict column allowlist
      const insertTables = [
        'business_profile',
        'clients',
        'invoices',
        'estimates',
        'expenses',
        'saved_items',
        'invoice_items',
        'estimate_items',
        'payments'
      ];

      for (final table in insertTables) {
        final rows = backup[table] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        for (final row in rows) {
          final sanitized = sanitizeRowForTable(table, row as Map);
          if (sanitized.isEmpty) continue;

          final keys = sanitized.keys.toList();
          final placeholders = List.filled(keys.length, '?').join(', ');
          final columns = keys.join(', ');
          final values = keys.map((k) => sanitized[k]).toList();

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
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file: Root payload must be a JSON object.');
    }
    importDatabaseFromJson(db, decoded);
  }
}
