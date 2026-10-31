import 'dart:ui';
import 'package:flutter/material.dart';

class AppPalette {
  // Light Palette: Tailwind Slate & Zinc
  static const Color lightScaffold = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White
  static const Color lightSecondary = Color(0xFFF1F5F9); // Slate 100
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200 hairline
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500
  static const Color lightTextMuted = Color(0xFF94A3B8); // Slate 400

  // Dark Palette: Obsidian OLED & Slate
  static const Color darkScaffold = Color(0xFF0B0F19); // Obsidian Canvas
  static const Color darkSurface = Color(0xFF0F172A); // Slate 900
  static const Color darkSecondary = Color(0xFF1E293B); // Slate 800
  static const Color darkBorder = Color(0xFF1E293B); // Slate 800 hairline
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextMuted = Color(0xFF64748B); // Slate 500

  // Accent Presets
  static const Color indigo = Color(0xFF4F46E5);
  static const Color emerald = Color(0xFF10B981);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color roseRed = Color(0xFFF43F5E);
  static const Color amberGold = Color(0xFFF59E0B);
  static const Color slateSteel = Color(0xFF475569);
}

class AppShadows {
  static const List<BoxShadow> cardLight = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.04),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.04),
      blurRadius: 6,
      spreadRadius: -1,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardDark = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.35),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.25),
      blurRadius: 10,
      spreadRadius: -2,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> dialogLight = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.08),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> dialogDark = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.60),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];
}

class FrostedGlassDialog extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;

  const FrostedGlassDialog({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blur = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xEB0F172A) : const Color(0xF5FFFFFF);
    final borderColor = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: isDark ? AppShadows.dialogDark : AppShadows.dialogLight,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class AppTheme {
  static const Color seedColor = AppPalette.indigo;

  static const List<Color> presetAccents = [
    AppPalette.indigo,
    AppPalette.emerald,
    AppPalette.royalBlue,
    AppPalette.roseRed,
    AppPalette.amberGold,
    AppPalette.slateSteel,
  ];

  static const double borderRadius = 12.0;
  static final BorderRadius geometryRadius = BorderRadius.circular(borderRadius);

  static const double dialogBorderRadius = 16.0;
  static final BorderRadius dialogRadius = BorderRadius.circular(dialogBorderRadius);

  static final BorderRadius pillRadius = BorderRadius.circular(9999);

  static TextTheme _applyTabularFigures(TextTheme base, {required Color primaryText, required Color secondaryText}) {
    const fontFeatures = [FontFeature.tabularFigures()];
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontFeatures: fontFeatures, color: primaryText),
      displayMedium: base.displayMedium?.copyWith(fontFeatures: fontFeatures, color: primaryText),
      displaySmall: base.displaySmall?.copyWith(fontFeatures: fontFeatures, color: primaryText),
      headlineLarge: base.headlineLarge?.copyWith(fontFeatures: fontFeatures, color: primaryText, fontWeight: FontWeight.bold),
      headlineMedium: base.headlineMedium?.copyWith(fontFeatures: fontFeatures, color: primaryText, fontWeight: FontWeight.bold),
      headlineSmall: base.headlineSmall?.copyWith(fontFeatures: fontFeatures, color: primaryText, fontWeight: FontWeight.bold),
      titleLarge: base.titleLarge?.copyWith(fontFeatures: fontFeatures, color: primaryText, fontWeight: FontWeight.bold),
      titleMedium: base.titleMedium?.copyWith(fontFeatures: fontFeatures, color: primaryText, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontFeatures: fontFeatures, color: primaryText, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontFeatures: fontFeatures, color: primaryText),
      bodyMedium: base.bodyMedium?.copyWith(fontFeatures: fontFeatures, color: primaryText),
      bodySmall: base.bodySmall?.copyWith(fontFeatures: fontFeatures, color: secondaryText),
      labelLarge: base.labelLarge?.copyWith(fontFeatures: fontFeatures, color: primaryText, fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontFeatures: fontFeatures, color: secondaryText),
      labelSmall: base.labelSmall?.copyWith(fontFeatures: fontFeatures, color: secondaryText),
    );
  }

  static ThemeData lightTheme({Color seed = seedColor}) {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: seed,
      onPrimary: Colors.white,
      primaryContainer: seed.withAlpha(25),
      onPrimaryContainer: seed,
      secondary: const Color(0xFF475569),
      onSecondary: Colors.white,
      secondaryContainer: AppPalette.lightSecondary,
      onSecondaryContainer: AppPalette.lightTextPrimary,
      surface: AppPalette.lightSurface,
      onSurface: AppPalette.lightTextPrimary,
      surfaceContainerHighest: AppPalette.lightSecondary,
      surfaceContainer: AppPalette.lightSurface,
      surfaceContainerLow: AppPalette.lightScaffold,
      outline: AppPalette.lightBorder,
      outlineVariant: AppPalette.lightBorder,
      error: const Color(0xFFEF4444),
      onError: Colors.white,
    );

    final baseTheme = ThemeData.light(useMaterial3: true);

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.lightScaffold,
      textTheme: _applyTabularFigures(
        baseTheme.textTheme,
        primaryText: AppPalette.lightTextPrimary,
        secondaryText: AppPalette.lightTextSecondary,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: geometryRadius,
          side: const BorderSide(color: AppPalette.lightBorder, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.lightSecondary.withAlpha(128),
        border: OutlineInputBorder(
          borderRadius: geometryRadius,
          borderSide: const BorderSide(color: AppPalette.lightBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: geometryRadius,
          borderSide: const BorderSide(color: AppPalette.lightBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: geometryRadius,
          borderSide: BorderSide(color: seed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: geometryRadius),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: geometryRadius),
          side: const BorderSide(color: AppPalette.lightBorder, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.lightSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: const BorderSide(color: AppPalette.lightBorder, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppPalette.lightSurface,
        indicatorColor: seed.withAlpha(30),
        selectedIconTheme: IconThemeData(color: seed),
        selectedLabelTextStyle: TextStyle(color: seed, fontWeight: FontWeight.bold),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.lightSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: seed.withAlpha(30),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.lightBorder,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }

  static ThemeData darkTheme({Color seed = seedColor}) {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: seed,
      onPrimary: Colors.white,
      primaryContainer: seed.withAlpha(45),
      onPrimaryContainer: Colors.white,
      secondary: const Color(0xFF94A3B8),
      onSecondary: const Color(0xFF0F172A),
      secondaryContainer: AppPalette.darkSecondary,
      onSecondaryContainer: AppPalette.darkTextPrimary,
      surface: AppPalette.darkSurface,
      onSurface: AppPalette.darkTextPrimary,
      surfaceContainerHighest: AppPalette.darkSecondary,
      surfaceContainer: AppPalette.darkSurface,
      surfaceContainerLow: AppPalette.darkScaffold,
      outline: AppPalette.darkBorder,
      outlineVariant: AppPalette.darkBorder,
      error: const Color(0xFFF87171),
      onError: Colors.black,
    );

    final baseTheme = ThemeData.dark(useMaterial3: true);

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.darkScaffold,
      textTheme: _applyTabularFigures(
        baseTheme.textTheme,
        primaryText: AppPalette.darkTextPrimary,
        secondaryText: AppPalette.darkTextSecondary,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: geometryRadius,
          side: const BorderSide(color: AppPalette.darkBorder, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.darkSecondary.withAlpha(128),
        border: OutlineInputBorder(
          borderRadius: geometryRadius,
          borderSide: const BorderSide(color: AppPalette.darkBorder, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: geometryRadius,
          borderSide: const BorderSide(color: AppPalette.darkBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: geometryRadius,
          borderSide: BorderSide(color: seed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: geometryRadius),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: geometryRadius),
          side: const BorderSide(color: AppPalette.darkBorder, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.darkSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: const BorderSide(color: AppPalette.darkBorder, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.darkSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppPalette.darkSurface,
        indicatorColor: seed.withAlpha(60),
        selectedIconTheme: IconThemeData(color: seed),
        selectedLabelTextStyle: TextStyle(color: seed, fontWeight: FontWeight.bold),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.darkSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: seed.withAlpha(60),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.darkBorder,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }
}
