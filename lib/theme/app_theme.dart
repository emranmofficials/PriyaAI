import 'package:flutter/material.dart';

/// PrivateAgent design system — a premium "Slate" deep theme with indigo
/// accents, in both dark and light variants.
class AppTheme {
  AppTheme._();

  // Luxury Obsidian & Purple palette (from official Priya AI branding)
  static const obsidian = Color(0xFF080410);
  static const obsidianSurface = Color(0xFF130B24);
  static const obsidianElevated = Color(0xFF1E1238);
  static const obsidianCard = Color(0xFF160D2B);
  static const borderViolet = Color(0xFF34225A);

  // Brand accents
  static const purplePrimary = Color(0xFFA855F7);
  static const purpleLight = Color(0xFFC084FC);
  static const magentaAccent = Color(0xFFE879F9);
  static const cyanAccent = Color(0xFF38BDF8);
  static const indigo = Color(0xFF8B5CF6);
  static const indigoLight = Color(0xFFA78BFA);

  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Neutral text
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  // Backward compatibility aliases
  static const slate50 = Color(0xFFFAF5FF);
  static const slate100 = textPrimary;
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = textSecondary;
  static const slate500 = textMuted;
  static const slate600 = Color(0xFF475569);
  static const slate700 = borderViolet;
  static const slate800 = obsidianElevated;
  static const slate900 = obsidianSurface;
  static const slate950 = obsidian;

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: purplePrimary,
      brightness: Brightness.dark,
      surface: obsidianSurface,
    ).copyWith(
      primary: purpleLight,
      onPrimary: obsidian,
      secondary: magentaAccent,
      tertiary: cyanAccent,
      surface: obsidianSurface,
      surfaceContainerHighest: obsidianElevated,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: borderViolet,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: obsidian,
      cardColor: obsidianCard,
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: purplePrimary,
      brightness: Brightness.light,
      surface: const Color(0xFFFAF5FF),
    ).copyWith(
      primary: const Color(0xFF9333EA),
      secondary: const Color(0xFFC026D3),
      surface: const Color(0xFFFAF5FF),
      surfaceContainerHighest: Colors.white,
      onSurface: const Color(0xFF0F172A),
      onSurfaceVariant: const Color(0xFF475569),
      outline: const Color(0xFFE9D5FF),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFFFAF5FF),
      cardColor: Colors.white,
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.4),
        thickness: 1,
      ),
    );
  }
}
