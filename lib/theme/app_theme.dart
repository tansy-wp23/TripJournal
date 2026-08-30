import 'package:flutter/material.dart';

import 'aurora_theme.dart';

abstract final class AppTheme {
  static final ThemeData light = _build(
    brightness: Brightness.light,
    background: const Color(0xFFF0F9FF),
    surface: const Color(0xFFFFFFFF),
    surfaceContainer: const Color(0xFFE8F5FA),
    primary: const Color(0xFF0369A1),
    onPrimary: Colors.white,
    secondary: const Color(0xFF0E7490),
    tertiary: const Color(0xFFC2410C),
    onTertiary: Colors.white,
    foreground: const Color(0xFF0C4A6E),
    muted: const Color(0xFF475569),
    outline: const Color(0xFFBAE6FD),
    error: const Color(0xFFB91C1C),
    onError: Colors.white,
    aurora: const AuroraTheme(
      heroStart: Color(0xFF11B7D5),
      heroMiddle: Color(0xFF4475D8),
      heroEnd: Color(0xFF8865D0),
      raisedSurface: Color(0xFFE8F5FA),
      onHero: Colors.white,
    ),
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    background: const Color(0xFF071521),
    surface: const Color(0xFF0D2233),
    surfaceContainer: const Color(0xFF143247),
    primary: const Color(0xFF38BDF8),
    onPrimary: const Color(0xFF062638),
    secondary: const Color(0xFF67E8F9),
    tertiary: const Color(0xFFFB923C),
    onTertiary: const Color(0xFF321000),
    foreground: const Color(0xFFE6F6FF),
    muted: const Color(0xFFA9C4D4),
    outline: const Color(0xFF1C4057),
    error: const Color(0xFFFCA5A5),
    onError: const Color(0xFF450A0A),
    aurora: const AuroraTheme(
      heroStart: Color(0xFF0E7490),
      heroMiddle: Color(0xFF3157B7),
      heroEnd: Color(0xFF6546A8),
      raisedSurface: Color(0xFF143247),
      onHero: Colors.white,
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceContainer,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color tertiary,
    required Color onTertiary,
    required Color foreground,
    required Color muted,
    required Color outline,
    required Color error,
    required Color onError,
    required AuroraTheme aurora,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          secondary: secondary,
          tertiary: tertiary,
          onTertiary: onTertiary,
          surface: surface,
          surfaceContainer: surfaceContainer,
          surfaceContainerLow: surface,
          surfaceContainerHigh: surfaceContainer,
          onSurface: foreground,
          onSurfaceVariant: muted,
          outline: outline,
          outlineVariant: outline.withValues(alpha: 0.62),
          error: error,
          onError: onError,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    final rounded14 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final rounded18 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return base.copyWith(
      extensions: [aurora],
      textTheme: base.textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: brightness == Brightness.light ? 1 : 0,
        margin: EdgeInsets.zero,
        shape: rounded18.copyWith(
          side: BorderSide(color: outline.withValues(alpha: 0.72)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded18,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: rounded14,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: rounded14,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: rounded14,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tertiary,
        foregroundColor: onTertiary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.16),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: rounded14,
      ),
    );
  }
}
