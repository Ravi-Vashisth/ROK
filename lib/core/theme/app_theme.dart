import 'dart:ui';
import 'package:flutter/material.dart';

class AppTheme {
  static const seedColor = Color(0xFF4F46E5); // Modern Indigo

  // Preset Accent Palette for customization
  static const List<Color> presetAccents = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF059669), // Emerald
    Color(0xFF2563EB), // Royal Blue
    Color(0xFFE11D48), // Rose
    Color(0xFFD97706), // Amber
    Color(0xFF475569), // Slate
  ];

  static TextTheme _withTabularFigures(TextTheme base) {
    const tabular = [FontFeature.tabularFigures()];
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontFeatures: tabular),
      displayMedium: base.displayMedium?.copyWith(fontFeatures: tabular),
      displaySmall: base.displaySmall?.copyWith(fontFeatures: tabular),
      headlineLarge: base.headlineLarge?.copyWith(fontFeatures: tabular),
      headlineMedium: base.headlineMedium?.copyWith(fontFeatures: tabular),
      headlineSmall: base.headlineSmall?.copyWith(fontFeatures: tabular),
      titleLarge: base.titleLarge?.copyWith(fontFeatures: tabular),
      titleMedium: base.titleMedium?.copyWith(fontFeatures: tabular),
      titleSmall: base.titleSmall?.copyWith(fontFeatures: tabular),
      bodyLarge: base.bodyLarge?.copyWith(fontFeatures: tabular),
      bodyMedium: base.bodyMedium?.copyWith(fontFeatures: tabular),
      bodySmall: base.bodySmall?.copyWith(fontFeatures: tabular),
      labelLarge: base.labelLarge?.copyWith(fontFeatures: tabular),
      labelMedium: base.labelMedium?.copyWith(fontFeatures: tabular),
      labelSmall: base.labelSmall?.copyWith(fontFeatures: tabular),
    );
  }

  static ThemeData lightTheme({Color seed = seedColor}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _withTabularFigures(ThemeData.light().textTheme),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      dialogTheme: const DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }

  static ThemeData darkTheme({Color seed = seedColor}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF0F172A), // Slate 900
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _withTabularFigures(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: const Color(0xFF0B0F19), // Deep Slate
      cardTheme: CardTheme(
        elevation: 0,
        color: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFF1E293B)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        fillColor: const Color(0xFF0A0F1D),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      dialogTheme: const DialogTheme(
        backgroundColor: Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }
}
