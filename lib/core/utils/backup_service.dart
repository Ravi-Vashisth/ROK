import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';

class _TableValidationRule {
  final Set<String> requiredNonEmptyStrings;
  final Set<String> requiredInts;
  final Set<String> optionalInts;
  final Set<String> optionalStrings;

  const _TableValidationRule({
    required this.requiredNonEmptyStrings,
    this.requiredInts = const {},
    this.optionalInts = const {},
    this.optionalStrings = const {},
  });
}

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
      'theme_mode',
      'accent_color',
      'updated_at',
      'deleted_at',
    },
    'clients': {
      'id',
      'name',
      'email',
      'phone',
      'address',
      'tax_id',
      'created_at',
      'updated_at',
      'deleted_at',
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
      'updated_at',
      'deleted_at',
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
      'updated_at',
      'deleted_at',
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
      'updated_at',
      'deleted_at',
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
      'updated_at',
      'deleted_at',
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
      'updated_at',
      'deleted_at',
    },
    'saved_items': {
      'id',
      'title',
      'sac_hsn',
      'default_price_cents',
      'description',
      'created_at',
      'updated_at',
      'deleted_at',
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
      'updated_at',
      'deleted_at',
    },
  };

  static const Map<String, _TableValidationRule> _tableRules = {
    'business_profile': _TableValidationRule(
      requiredNonEmptyStrings: {'id', 'business_name'},
      optionalInts: {
        'currency_decimals',
        'next_invoice_number',
        'default_pst_rate_percentage',
        'accent_color',
      },
      optionalStrings: {
        'email',
        'phone',
        'address',
        'tax_id',
        'payment_details',
        'currency_symbol',
        'currency_code',
        'default_terms',
        'default_notes',
        'logo_base64',
        'signature_base64',
        'signature_label',
        'invoice_prefix',
        'estimate_prefix',
        'payment_qr_payload',
        'default_tax_mode',
        'theme_mode',
        'updated_at',
        'deleted_at',
      },
    ),
    'clients': _TableValidationRule(
      requiredNonEmptyStrings: {'id', 'name', 'created_at'},
      optionalStrings: {
        'email',
        'phone',
        'address',
        'tax_id',
        'updated_at',
        'deleted_at',
      },
    ),
    'invoices': _TableValidationRule(
      requiredNonEmptyStrings: {
        'id',
        'client_id',
        'invoice_number',
        'status',
        'created_at',
      },
      requiredInts: {'subtotal_cents', 'tax_cents', 'total_cents'},
      optionalInts: {
        'discount_value',
        'discount_cents',
        'currency_decimals',
        'pst_rate_percentage',
      },
      optionalStrings: {
        'issue_date',
        'due_date',
        'payment_terms',
        'terms',
        'notes',
        'discount_type',
        'po_number',
        'currency_code',
        'currency_symbol',
        'tax_mode',
        'tax_exemption_id',
        'updated_at',
        'deleted_at',
      },
    ),
    'invoice_items': _TableValidationRule(
      requiredNonEmptyStrings: {'id', 'invoice_id', 'description', 'created_at'},
      requiredInts: {'quantity', 'unit_price_cents', 'total_cents'},
      optionalInts: {'tax_rate_percentage', 'tax_cents'},
      optionalStrings: {'sac_hsn', 'updated_at', 'deleted_at'},
    ),
    'estimates': _TableValidationRule(
      requiredNonEmptyStrings: {
        'id',
        'client_id',
        'estimate_number',
        'status',
        'issue_date',
        'expiry_date',
        'created_at',
      },
      requiredInts: {'subtotal_cents', 'tax_cents', 'total_cents'},
      optionalInts: {
        'discount_value',
        'discount_cents',
        'currency_decimals',
        'pst_rate_percentage',
      },
      optionalStrings: {
        'converted_invoice_id',
        'terms',
        'notes',
        'discount_type',
        'po_number',
        'currency_code',
        'currency_symbol',
        'tax_mode',
        'tax_exemption_id',
        'updated_at',
        'deleted_at',
      },
    ),
    'estimate_items': _TableValidationRule(
      requiredNonEmptyStrings: {'id', 'estimate_id', 'description', 'created_at'},
      requiredInts: {'quantity', 'unit_price_cents', 'total_cents'},
      optionalInts: {'tax_rate_percentage', 'tax_cents'},
      optionalStrings: {'sac_hsn', 'updated_at', 'deleted_at'},
    ),
    'expenses': _TableValidationRule(
      requiredNonEmptyStrings: {
        'id',
        'category',
        'vendor',
        'expense_date',
        'created_at',
      },
      requiredInts: {'amount_cents'},
      optionalInts: {'tax_cents'},
      optionalStrings: {
        'notes',
        'receipt_base64',
        'receipt_name',
        'updated_at',
        'deleted_at',
      },
    ),
    'saved_items': _TableValidationRule(
      requiredNonEmptyStrings: {'id', 'title', 'created_at'},
      requiredInts: {'default_price_cents'},
      optionalStrings: {'sac_hsn', 'description', 'updated_at', 'deleted_at'},
    ),
    'payments': _TableValidationRule(
      requiredNonEmptyStrings: {
        'id',
        'invoice_id',
        'payment_method',
        'payment_date',
        'created_at',
      },
      requiredInts: {'amount_cents'},
      optionalInts: {'amount_received_cents', 'tds_cents'},
      optionalStrings: {'reference_number', 'notes', 'updated_at', 'deleted_at'},
    ),
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

  /// Validates NOT NULL fields and column value types for a single row in [table].
  /// Throws [FormatException] on any missing mandatory column or type mismatch.
  static void validateTableRow(
    String table,
    Map<dynamic, dynamic> rawRow,
    int rowIndex,
  ) {
    final rule = _tableRules[table];
    if (rule == null) {
      throw FormatException('Invalid backup file: Unsupported table "$table".');
    }

    for (final col in rule.requiredNonEmptyStrings) {
      final val = rawRow[col];
      if (val is! String || val.trim().isEmpty) {
        throw FormatException(
          'Invalid backup file: Table "$table" row ${rowIndex + 1} missing required non-empty string "$col".',
        );
      }
    }

    for (final col in rule.requiredInts) {
      final val = rawRow[col];
      if (val is! int) {
        throw FormatException(
          'Invalid backup file: Table "$table" row ${rowIndex + 1} requires integer value for "$col".',
        );
      }
    }

    for (final col in rule.optionalInts) {
      if (!rawRow.containsKey(col)) continue;
      final val = rawRow[col];
      if (val != null && val is! int) {
        throw FormatException(
          'Invalid backup file: Table "$table" row ${rowIndex + 1} expected integer (or null) for "$col".',
        );
      }
    }

    for (final col in rule.optionalStrings) {
      if (!rawRow.containsKey(col)) continue;
      final val = rawRow[col];
      if (val != null && val is! String) {
        throw FormatException(
          'Invalid backup file: Table "$table" row ${rowIndex + 1} expected string (or null) for "$col".',
        );
      }
    }
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
      final ResultSet result = db.select('SELECT * FROM $table');
      backup[table] = result.map((row) => Map<String, dynamic>.from(row)).toList();
    }

    backup['version'] = 1;
    backup['exported_at'] = DateTime.now().toUtc().toIso8601String();
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
      for (int i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is! Map) {
          throw FormatException(
              'Invalid backup file: Records in "$table" must be JSON objects.');
        }
        validateTableRow(table, item, i);
      }
    }
  }

  static void importDatabaseFromJson(Database db, Map<String, dynamic> backup) {
    validateBackupMap(backup);

    db.execute('PRAGMA foreign_keys = ON;');
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

      final fallbackUpdatedAt = DateTime.now().toUtc().toIso8601String();

      for (final table in insertTables) {
        final rows = backup[table] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        for (final row in rows) {
          final sanitized = sanitizeRowForTable(table, row as Map);
          if (sanitized.isEmpty) continue;

          final existingUpdatedAt = sanitized['updated_at'];
          if (existingUpdatedAt == null ||
              (existingUpdatedAt is String && existingUpdatedAt.trim().isEmpty)) {
            final created = sanitized['created_at'];
            sanitized['updated_at'] =
                (created is String && created.trim().isNotEmpty)
                    ? created
                    : fallbackUpdatedAt;
          }

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

      final fkViolations = db.select('PRAGMA foreign_key_check;');
      if (fkViolations.isNotEmpty) {
        throw const FormatException(
          'Invalid backup file: Foreign key integrity check failed (orphaned invoice, item, estimate, or payment references).',
        );
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
