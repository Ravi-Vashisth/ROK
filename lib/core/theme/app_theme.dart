import 'dart:ui';
import 'package:flutter/material.dart';

class AppTheme {
  static const Color seedColor = Color(0xFF4F46E5); // Modern Indigo

  static const List<Color> presetAccents = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF059669), // Emerald
    Color(0xFF2563EB), // Royal Blue
    Color(0xFFE11D48), // Rose
    Color(0xFFD97706), // Amber
    Color(0xFF475569), // Slate
  ];

  static const double borderRadius = 12.0;
  static final BorderRadius geometryRadius = BorderRadius.circular(borderRadius);

  static TextTheme _applyTabularFigures(TextTheme base) {
    const fontFeatures = [FontFeature.tabularFigures()];
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontFeatures: fontFeatures),
      displayMedium: base.displayMedium?.copyWith(fontFeatures: fontFeatures),
      displaySmall: base.displaySmall?.copyWith(fontFeatures: fontFeatures),
      headlineLarge: base.headlineLarge?.copyWith(fontFeatures: fontFeatures),
      headlineMedium: base.headlineMedium?.copyWith(fontFeatures: fontFeatures),
      headlineSmall: base.headlineSmall?.copyWith(fontFeatures: fontFeatures),
      titleLarge: base.titleLarge?.copyWith(fontFeatures: fontFeatures),
      titleMedium: base.titleMedium?.copyWith(fontFeatures: fontFeatures),
      titleSmall: base.titleSmall?.copyWith(fontFeatures: fontFeatures),
      bodyLarge: base.bodyLarge?.copyWith(fontFeatures: fontFeatures),
      bodyMedium: base.bodyMedium?.copyWith(fontFeatures: fontFeatures),
      bodySmall: base.bodySmall?.copyWith(fontFeatures: fontFeatures),
      labelLarge: base.labelLarge?.copyWith(fontFeatures: fontFeatures),
      labelMedium: base.labelMedium?.copyWith(fontFeatures: fontFeatures),
      labelSmall: base.labelSmall?.copyWith(fontFeatures: fontFeatures),
    );
  }

  static ThemeData lightTheme({Color seed = seedColor}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    final baseTheme = ThemeData.light(useMaterial3: true);

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      textTheme: _applyTabularFigures(baseTheme.textTheme),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: geometryRadius,
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: geometryRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: geometryRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: geometryRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: geometryRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: geometryRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData darkTheme({Color seed = seedColor}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF0F172A),
    );

    final baseTheme = ThemeData.dark(useMaterial3: true);

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF020617),
      textTheme: _applyTabularFigures(baseTheme.textTheme),
      cardTheme: CardThemeData(
        color: const Color(0xFF0F172A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: geometryRadius,
          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: geometryRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: geometryRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: geometryRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: geometryRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: geometryRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
