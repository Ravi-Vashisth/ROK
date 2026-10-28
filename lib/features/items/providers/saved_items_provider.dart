import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/id_generator.dart';
import '../models/saved_item.dart';

class SavedItemsNotifier extends StateNotifier<List<SavedItem>> {
  final Database _db;

  SavedItemsNotifier(this._db) : super([]) {
    loadItems();
  }

  void loadItems() {
    try {
      final ResultSet results = _db.select(
        'SELECT * FROM saved_items ORDER BY title ASC',
      );
      final items = results.map((row) => SavedItem.fromRow(row)).toList();
      
      // If table is empty, seed common default preset items
      if (items.isEmpty) {
        _seedDefaults();
        final ResultSet fresh = _db.select('SELECT * FROM saved_items ORDER BY title ASC');
        state = fresh.map((row) => SavedItem.fromRow(row)).toList();
      } else {
        state = items;
      }
    } catch (_) {
      state = [];
    }
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
      INSERT INTO saved_items (id, title, default_price_cents, description, created_at)
      VALUES (?, ?, ?, ?, ?)
    ''');
    try {
      for (final d in defaults) {
        stmt.execute([
          generateUniqueId(),
          d['title'] as String,
          d['price'] as int,
          d['desc'] as String,
          now,
        ]);
      }
    } finally {
      stmt.dispose();
    }
  }

  void addItem({
    required String title,
    required int defaultPriceCents,
    String description = '',
  }) {
    if (title.trim().isEmpty) return;

    final id = generateUniqueId();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final stmt = _db.prepare('''
      INSERT INTO saved_items (id, title, default_price_cents, description, created_at)
      VALUES (?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute([id, title.trim(), defaultPriceCents, description.trim(), createdAt]);
    } finally {
      stmt.dispose();
    }

    loadItems();
  }

  void updateItem({
    required String id,
    required String title,
    required int defaultPriceCents,
    String description = '',
  }) {
    if (title.trim().isEmpty) return;

    final stmt = _db.prepare('''
      UPDATE saved_items 
      SET title = ?, default_price_cents = ?, description = ?
      WHERE id = ?
    ''');
    try {
      stmt.execute([title.trim(), defaultPriceCents, description.trim(), id]);
    } finally {
      stmt.dispose();
    }
    loadItems();
  }

  void deleteItem(String id) {
    _db.execute('DELETE FROM saved_items WHERE id = ?', [id]);
    loadItems();
  }
}

final savedItemsProvider =
    StateNotifierProvider<SavedItemsNotifier, List<SavedItem>>((ref) {
  return SavedItemsNotifier(ref.watch(databaseProvider));
});
