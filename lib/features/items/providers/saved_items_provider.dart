import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:billing_app/core/database/database_provider.dart';
import 'package:billing_app/core/utils/id_generator.dart';
import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/features/items/models/saved_item.dart';

class SavedItemsNotifier extends StateNotifier<List<SavedItem>> {
  final Database _db;

  SavedItemsNotifier(this._db) : super([]) {
    loadItems();
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

  void loadItems() {
    final totalCountRes = _db.select('SELECT COUNT(*) AS cnt FROM saved_items');
    final totalRows = (totalCountRes.first['cnt'] as int?) ?? 0;
    if (totalRows == 0) {
      _seedDefaults();
    }
    final ResultSet results = _db.select(
      'SELECT * FROM saved_items WHERE deleted_at IS NULL ORDER BY title ASC',
    );
    state = results.map((row) => SavedItem.fromRow(row)).toList();
  }

  void _seedDefaults() {
    final now = DateTime.now().toUtc().toIso8601String();
    final defaults = [
      {'title': 'Software Architecture & Development', 'price': 10000, 'desc': 'Senior full-stack engineering rate'},
      {'title': 'UI/UX Interface Design Mockups', 'price': 8500, 'desc': 'High-fidelity Figma mockups and wireframes'},
      {'title': 'System Maintenance & Support (Monthly)', 'price': 5000, 'desc': 'Ongoing bug fixes and infrastructure upkeep'},
      {'title': 'Technical Consulting & Discovery', 'price': 12000, 'desc': 'Strategic tech roadmap and scoping session'},
    ];

    final stmt = _db.prepare('''
      INSERT INTO saved_items (id, title, default_price_cents, description, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
    ''');
    try {
      for (final d in defaults) {
        stmt.execute([
          generateUniqueId(),
          d['title'] as String,
          d['price'] as int,
          d['desc'] as String,
          now,
          now,
        ]);
      }
    } finally {
      stmt.dispose();
    }
  }

  void addItem({
    required String title,
    String sacHsn = '',
    required int defaultPriceCents,
    String description = '',
    String? currencyCode,
    int? currencyDecimals,
  }) {
    if (title.trim().isEmpty) return;

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
      INSERT INTO saved_items (id, title, sac_hsn, default_price_cents, description, currency_code, currency_decimals, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute([
        id,
        title.trim(),
        sacHsn.trim(),
        defaultPriceCents,
        description.trim(),
        resolvedCode,
        resolvedDecimals,
        nowIso,
        nowIso,
      ]);
    } finally {
      stmt.dispose();
    }

    loadItems();
  }

  void updateItem({
    required String id,
    required String title,
    String sacHsn = '',
    required int defaultPriceCents,
    String description = '',
    String? currencyCode,
    int? currencyDecimals,
  }) {
    if (title.trim().isEmpty) return;

    final updatedAt = DateTime.now().toUtc().toIso8601String();
    final existing = _db.select(
      'SELECT currency_code, currency_decimals FROM saved_items WHERE id = ? AND deleted_at IS NULL LIMIT 1',
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
      UPDATE saved_items 
      SET title = ?, sac_hsn = ?, default_price_cents = ?, description = ?, currency_code = ?, currency_decimals = ?, updated_at = ?
      WHERE id = ? AND deleted_at IS NULL
    ''');
    try {
      stmt.execute([
        title.trim(),
        sacHsn.trim(),
        defaultPriceCents,
        description.trim(),
        resolvedCode,
        resolvedDecimals,
        updatedAt,
        id,
      ]);
    } finally {
      stmt.dispose();
    }
    loadItems();
  }

  void deleteItem(String id) {
    final deletedAt = DateTime.now().toUtc().toIso8601String();
    final stmt = _db.prepare(
      'UPDATE saved_items SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL',
    );
    try {
      stmt.execute([deletedAt, deletedAt, id]);
    } finally {
      stmt.dispose();
    }
    loadItems();
  }
}

final savedItemsProvider =
    StateNotifierProvider<SavedItemsNotifier, List<SavedItem>>((ref) {
  return SavedItemsNotifier(ref.watch(databaseProvider));
});
