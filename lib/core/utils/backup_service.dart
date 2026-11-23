import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:sqlite3/sqlite3.dart';
import 'package:billing_app/core/utils/id_generator.dart';
import 'package:billing_app/core/utils/money_utils.dart';

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
      'currency_code',
      'currency_decimals',
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
      'currency_code',
      'currency_decimals',
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
      optionalInts: {'tax_cents', 'currency_decimals'},
      optionalStrings: {
        'notes',
        'receipt_base64',
        'receipt_name',
        'currency_code',
        'updated_at',
        'deleted_at',
      },
    ),
    'saved_items': _TableValidationRule(
      requiredNonEmptyStrings: {'id', 'title', 'created_at'},
      requiredInts: {'default_price_cents'},
      optionalInts: {'currency_decimals'},
      optionalStrings: {
        'sac_hsn',
        'description',
        'currency_code',
        'updated_at',
        'deleted_at',
      },
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

  static int? _asInt(dynamic v) => v is int ? v : null;

  /// Normalizes React Web JSON backups (`businessProfile` object, nested `invoice.items` /
  /// `estimate.items`, camelCase `savedItems`, and `paid_cents` without `payments` table)
  /// into canonical Flutter SQLite snapshot structure before strict validation.
  static Map<String, dynamic> normalizeBackupPayloadForFlutter(
    Map<String, dynamic> raw,
  ) {
    final normalized = <String, dynamic>{};
    for (final entry in raw.entries) {
      normalized[entry.key] = entry.value;
    }

    final fallbackTs = (raw['exported_at'] is String &&
            (raw['exported_at'] as String).trim().isNotEmpty)
        ? (raw['exported_at'] as String).trim()
        : DateTime.now().toUtc().toIso8601String();
    final fallbackDate = fallbackTs.length >= 10
        ? fallbackTs.substring(0, 10)
        : '1970-01-01';

    // Reject explicitly malformed React businessProfile early so validation catches it.
    if (raw.containsKey('businessProfile') && raw['businessProfile'] is! Map) {
      throw const FormatException(
        'Invalid backup file: "businessProfile" must be a JSON object.',
      );
    }

    // Normalize React camelCase `businessProfile` object -> Flutter `business_profile` list.
    if (!normalized.containsKey('business_profile')) {
      if (raw['businessProfile'] is Map) {
        final prof = Map<String, dynamic>.from(raw['businessProfile'] as Map);
        prof.putIfAbsent('id', () => 'default');
        if (prof['business_name'] is! String ||
            (prof['business_name'] as String).trim().isEmpty) {
          prof['business_name'] = 'My Freelance Studio';
        }
        // React stores accent_color preset names as strings while SQLite expects int ARGB.
        if (prof['accent_color'] is String) {
          prof.remove('accent_color');
        }
        normalized['business_profile'] = [prof];
      } else if (raw['clients'] is List && raw['invoices'] is List) {
        // React snapshot without businessProfile key still represents a valid user backup.
        normalized['business_profile'] = [
          <String, dynamic>{
            'id': 'default',
            'business_name': 'My Freelance Studio',
            'currency_code': 'USD',
            'currency_symbol': '\$',
            'currency_decimals': 2,
          }
        ];
      }
    }

    // Normalize clients created_at fallback when exported from Web local state.
    if (normalized['clients'] is List) {
      final rawClients = normalized['clients'] as List;
      normalized['clients'] = rawClients.map((c) {
        if (c is! Map) return c;
        final copy = Map<String, dynamic>.from(c);
        if (copy['created_at'] == null) {
          copy['created_at'] = fallbackTs;
        }
        return copy;
      }).toList();
    }

    // Flatten nested React invoice.items -> `invoice_items` and synthesize `payments` if needed.
    final bool hadExplicitInvoiceItems = normalized['invoice_items'] is List;
    final bool hadExplicitPayments = normalized['payments'] is List;
    final List<dynamic> flattenedInvItems = hadExplicitInvoiceItems
        ? List<dynamic>.from(normalized['invoice_items'] as List)
        : <dynamic>[];
    final List<dynamic> synthesizedPayments = hadExplicitPayments
        ? List<dynamic>.from(normalized['payments'] as List)
        : <dynamic>[];

    if (normalized['invoices'] is List) {
      final rawInvoices = normalized['invoices'] as List;
      normalized['invoices'] = rawInvoices.map((inv) {
        if (inv is! Map) return inv;
        final copy = Map<String, dynamic>.from(inv);
        if (copy['created_at'] == null) {
          copy['created_at'] = fallbackTs;
        }
        final invId = copy['id'];
        final invCreated =
            copy['created_at'] is String && (copy['created_at'] as String).trim().isNotEmpty
                ? copy['created_at'] as String
                : fallbackTs;

        final nestedItems = copy.remove('items');
        if (!hadExplicitInvoiceItems && nestedItems is List && invId is String && invId.trim().isNotEmpty) {
          for (final rawItem in nestedItems) {
            if (rawItem is! Map) {
              flattenedInvItems.add(rawItem);
              continue;
            }
            final qty = _asInt(rawItem['quantity']) ?? 1;
            final unitPrice = rawItem['unit_price_cents'] ?? rawItem['unitPriceCents'];
            final unitInt = _asInt(unitPrice);
            final taxRate = _asInt(rawItem['tax_rate_percentage'] ?? rawItem['taxSlab']) ?? 0;
            final explicitTotal = rawItem['total_cents'] ?? rawItem['totalCents'];
            final totalVal = explicitTotal ?? (unitInt != null ? qty * unitInt : null);
            final explicitTax = rawItem['tax_cents'] ?? rawItem['taxCents'];
            final taxVal = explicitTax ??
                (totalVal is int ? calculateTaxCents(totalVal, taxRate) : 0);

            flattenedInvItems.add(<String, dynamic>{
              'id': (rawItem['id'] is String && (rawItem['id'] as String).trim().isNotEmpty)
                  ? rawItem['id']
                  : generateUniqueId(),
              'invoice_id': invId,
              'description': rawItem['description'],
              'sac_hsn': rawItem['sac_hsn'] ?? rawItem['sacHsn'] ?? '',
              'quantity': rawItem['quantity'] ?? 1,
              'unit_price_cents': unitPrice,
              'tax_rate_percentage': taxRate,
              'tax_cents': taxVal,
              'total_cents': totalVal,
              'created_at': rawItem['created_at'] ?? invCreated,
            });
          }
        }

        final paidCents = _asInt(copy['paid_cents']);
        if (!hadExplicitPayments &&
            paidCents != null &&
            paidCents > 0 &&
            invId is String &&
            invId.trim().isNotEmpty) {
          final payDate = (copy['issue_date'] is String &&
                  (copy['issue_date'] as String).trim().isNotEmpty)
              ? (copy['issue_date'] as String).trim()
              : fallbackDate;
          synthesizedPayments.add(<String, dynamic>{
            'id': generateUniqueId(),
            'invoice_id': invId,
            'amount_cents': paidCents,
            'amount_received_cents': paidCents,
            'tds_cents': 0,
            'reference_number': '',
            'payment_method': 'Imported Balance',
            'payment_date': payDate,
            'notes': 'Migrated from Web backup',
            'created_at': invCreated,
          });
        }
        return copy;
      }).toList();

      if (flattenedInvItems.isNotEmpty || hadExplicitInvoiceItems) {
        normalized['invoice_items'] = flattenedInvItems;
      }
      if (synthesizedPayments.isNotEmpty || hadExplicitPayments) {
        normalized['payments'] = synthesizedPayments;
      }
    }

    // Flatten nested React estimate.items -> `estimate_items`.
    final bool hadExplicitEstimateItems = normalized['estimate_items'] is List;
    final List<dynamic> flattenedEstItems = hadExplicitEstimateItems
        ? List<dynamic>.from(normalized['estimate_items'] as List)
        : <dynamic>[];

    if (normalized['estimates'] is List) {
      final rawEstimates = normalized['estimates'] as List;
      normalized['estimates'] = rawEstimates.map((est) {
        if (est is! Map) return est;
        final copy = Map<String, dynamic>.from(est);
        if (copy['created_at'] == null) {
          copy['created_at'] = fallbackTs;
        }
        final estId = copy['id'];
        final estCreated =
            copy['created_at'] is String && (copy['created_at'] as String).trim().isNotEmpty
                ? copy['created_at'] as String
                : fallbackTs;
        final nestedItems = copy.remove('items');
        if (!hadExplicitEstimateItems && nestedItems is List && estId is String && estId.trim().isNotEmpty) {
          for (final rawItem in nestedItems) {
            if (rawItem is! Map) {
              flattenedEstItems.add(rawItem);
              continue;
            }
            final qty = _asInt(rawItem['quantity']) ?? 1;
            final unitPrice = rawItem['unit_price_cents'] ?? rawItem['unitPriceCents'];
            final unitInt = _asInt(unitPrice);
            final taxRate = _asInt(rawItem['tax_rate_percentage'] ?? rawItem['taxSlab']) ?? 0;
            final explicitTotal = rawItem['total_cents'] ?? rawItem['totalCents'];
            final totalVal = explicitTotal ?? (unitInt != null ? qty * unitInt : null);
            final explicitTax = rawItem['tax_cents'] ?? rawItem['taxCents'];
            final taxVal = explicitTax ??
                (totalVal is int ? calculateTaxCents(totalVal, taxRate) : 0);

            flattenedEstItems.add(<String, dynamic>{
              'id': (rawItem['id'] is String && (rawItem['id'] as String).trim().isNotEmpty)
                  ? rawItem['id']
                  : generateUniqueId(),
              'estimate_id': estId,
              'description': rawItem['description'],
              'sac_hsn': rawItem['sac_hsn'] ?? rawItem['sacHsn'] ?? '',
              'quantity': rawItem['quantity'] ?? 1,
              'unit_price_cents': unitPrice,
              'tax_rate_percentage': taxRate,
              'tax_cents': taxVal,
              'total_cents': totalVal,
              'created_at': rawItem['created_at'] ?? estCreated,
            });
          }
        }
        return copy;
      }).toList();

      if (flattenedEstItems.isNotEmpty || hadExplicitEstimateItems) {
        normalized['estimate_items'] = flattenedEstItems;
      }
    }

    // Normalize React expenses (`total_cents` minus `tax_cents` when `amount_cents` omitted).
    if (normalized['expenses'] is List) {
      final rawExpenses = normalized['expenses'] as List;
      normalized['expenses'] = rawExpenses.map((exp) {
        if (exp is! Map) return exp;
        final copy = Map<String, dynamic>.from(exp);
        if (copy['created_at'] == null) {
          copy['created_at'] = fallbackTs;
        }
        if (copy['amount_cents'] == null && copy['total_cents'] is int) {
          final totalCents = copy['total_cents'] as int;
          final taxCents = copy['tax_cents'] is int ? (copy['tax_cents'] as int) : 0;
          copy['amount_cents'] = (totalCents - taxCents).clamp(0, totalCents);
        }
        if (copy['currency_code'] == null && copy.containsKey('currencyCode')) {
          copy['currency_code'] = copy['currencyCode'];
        }
        if (copy['currency_decimals'] == null && copy.containsKey('currencyDecimals')) {
          copy['currency_decimals'] = copy['currencyDecimals'];
        }
        return copy;
      }).toList();
    }

    // Normalize React camelCase `savedItems` -> Flutter `saved_items`.
    if (!normalized.containsKey('saved_items') && raw.containsKey('savedItems')) {
      final rawSaved = raw['savedItems'];
      if (rawSaved is! List) {
        throw const FormatException(
          'Invalid backup file: Table "saved_items" must be a JSON array.',
        );
      }
      normalized['saved_items'] = rawSaved.map((it) {
        if (it is! Map) return it;
        final copy = Map<String, dynamic>.from(it);
        if (copy['created_at'] == null) {
          copy['created_at'] = fallbackTs;
        }
        if (copy['default_price_cents'] == null && copy.containsKey('defaultPriceCents')) {
          copy['default_price_cents'] = copy['defaultPriceCents'];
        }
        if (copy['sac_hsn'] == null && copy.containsKey('sacHsn')) {
          copy['sac_hsn'] = copy['sacHsn'];
        }
        if (copy['currency_code'] == null && copy.containsKey('currencyCode')) {
          copy['currency_code'] = copy['currencyCode'];
        }
        if (copy['currency_decimals'] == null && copy.containsKey('currencyDecimals')) {
          copy['currency_decimals'] = copy['currencyDecimals'];
        }
        return copy;
      }).toList();
    }

    return normalized;
  }

  static void validateBackupMap(Map<String, dynamic> backup) {
    final normalized = normalizeBackupPayloadForFlutter(backup);
    if (!normalized.containsKey('business_profile') ||
        !normalized.containsKey('clients') ||
        !normalized.containsKey('invoices')) {
      throw const FormatException(
          'Invalid backup file: The selected file is not a valid Freelance Ledger database snapshot.');
    }

    for (final table in allowedTableColumns.keys) {
      if (!normalized.containsKey(table)) continue;
      final value = normalized[table];
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
    final normalized = normalizeBackupPayloadForFlutter(backup);
    validateBackupMap(normalized);

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
        final rows = normalized[table] as List<dynamic>?;
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

  static Uint8List _encodeSnapshotToUtf8Bytes(Map<String, dynamic> snapshot) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(snapshot);
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  static Map<String, dynamic> _decodeAndValidateBackupBytes(Uint8List bytes) {
    final jsonStr = utf8.decode(bytes);
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid backup file: Root payload must be a JSON object.',
      );
    }
    final normalized = normalizeBackupPayloadForFlutter(decoded);
    validateBackupMap(normalized);
    return normalized;
  }

  /// Reads tables synchronously on the DB owner thread and offloads pretty JSON
  /// formatting + UTF-8 encoding to a background isolate via [Isolate.run].
  static Future<Uint8List> exportDatabaseToJsonBytesAsync(Database db) {
    final snapshot = exportDatabaseToJson(db);
    return Isolate.run(() => _encodeSnapshotToUtf8Bytes(snapshot));
  }

  /// Offloads UTF-8 decoding, JSON parsing, normalization, and strict schema validation
  /// to a background isolate via [Isolate.run] before touching SQLite on the main thread.
  static Future<Map<String, dynamic>> decodeAndValidateBackupBytesAsync(
    List<int> rawBytes,
  ) {
    final payload = rawBytes is Uint8List ? rawBytes : Uint8List.fromList(rawBytes);
    return Isolate.run(() => _decodeAndValidateBackupBytes(payload));
  }

  static void importFromJsonString(Database db, String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file: Root payload must be a JSON object.');
    }
    importDatabaseFromJson(db, decoded);
  }
}
