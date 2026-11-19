import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import 'package:billing_app/core/database/database_provider.dart';
import 'package:billing_app/core/theme/app_theme.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Database? _db;

  ThemeModeNotifier([this._db]) : super(ThemeMode.system) {
    _load();
  }

  void _load() {
    final db = _db;
    if (db == null) return;
    final rows = db.select(
      "SELECT theme_mode FROM business_profile WHERE id = 'default' LIMIT 1;",
    );
    if (rows.isNotEmpty) {
      state = AppTheme.parseThemeModeStorage(rows.first['theme_mode'] as String?);
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    final db = _db;
    if (db == null) return;
    db.execute(
      "UPDATE business_profile SET theme_mode = ?, updated_at = ? WHERE id = 'default';",
      [AppTheme.themeModeToStorage(mode), DateTime.now().toUtc().toIso8601String()],
    );
  }

  /// Cycles through System -> Light -> Dark -> System
  void cycleThemeMode() {
    switch (state) {
      case ThemeMode.system:
        setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.light:
        setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setThemeMode(ThemeMode.system);
        break;
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final db = ref.watch(databaseProvider);
  return ThemeModeNotifier(db);
});

class AccentColorNotifier extends StateNotifier<Color> {
  final Database? _db;

  AccentColorNotifier([this._db]) : super(AppTheme.seedColor) {
    _load();
  }

  void _load() {
    final db = _db;
    if (db == null) return;
    final rows = db.select(
      "SELECT accent_color FROM business_profile WHERE id = 'default' LIMIT 1;",
    );
    if (rows.isNotEmpty) {
      final raw = rows.first['accent_color'];
      final intVal = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      state = AppTheme.resolveAccentColor(intVal);
    }
  }

  void setAccentColor(Color color) {
    final resolved = AppTheme.resolveAccentColor(color.toARGB32());
    state = resolved;
    final db = _db;
    if (db == null) return;
    db.execute(
      "UPDATE business_profile SET accent_color = ?, updated_at = ? WHERE id = 'default';",
      [resolved.toARGB32(), DateTime.now().toUtc().toIso8601String()],
    );
  }
}

final accentColorProvider = StateNotifierProvider<AccentColorNotifier, Color>((ref) {
  final db = ref.watch(databaseProvider);
  return AccentColorNotifier(db);
});
