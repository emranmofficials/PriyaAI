import 'package:flutter/material.dart';

/// Maya & Priya AI unified design system — Luxury Cyberpunk AMOLED palette
/// featuring deep void black canvas, glowing neon cyan/violet HUD accents,
/// glassmorphic frosted cards, and dynamic edge-glow borders.
class AppTheme {
  AppTheme._();

  // Maya Deep Void & AMOLED canvas
  static const obsidian = Color(0xFF050508);
  static const obsidianSurface = Color(0xFF0D0B14);
  static const obsidianElevated = Color(0xFF161224);
  static const obsidianCard = Color(0xFF120E1C);
  static const borderViolet = Color(0xFF281C44);
  static const borderGlow = Color(0xFF583296);

  // Maya Signature Neon Accents
  static const neonCyan = Color(0xFF00E5FF);
  static const neonCyanLight = Color(0xFF6EFAFF);
  static const neonViolet = Color(0xFFA855F7);
  static const neonPurpleLight = Color(0xFFC084FC);
  static const neonMagenta = Color(0xFFFF2A85);
  static const neonEmerald = Color(0xFF00F5D4);
  static const electricBlue = Color(0xFF2563EB);

  // Status & Feedback
  static const success = Color(0xFF00F5D4);
  static const danger = Color(0xFFFF3366);
  static const warning = Color(0xFFFFB800);

  // Typography Palette
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF9E9AA7);
  static const textMuted = Color(0xFF5E596B);

  // Backward compatibility aliases
  static const purplePrimary = neonViolet;
  static const purpleLight = neonPurpleLight;
  static const magentaAccent = neonMagenta;
  static const cyanAccent = neonCyan;
  static const indigo = neonViolet;
  static const indigoLight = neonPurpleLight;
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
      seedColor: neonViolet,
      brightness: Brightness.dark,
      surface: obsidianSurface,
    ).copyWith(
      primary: neonViolet,
      onPrimary: obsidian,
      secondary: neonCyan,
      tertiary: neonMagenta,
      surface: obsidianSurface,
      surfaceContainerHighest: obsidianElevated,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: borderViolet,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: obsidian,
      cardColor: obsidianCard,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: obsidianElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderViolet, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: obsidianSurface,
        modalBackgroundColor: obsidianSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: obsidianElevated,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderViolet),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData light() => dark(); // Maya is strictly dark mode first
}
