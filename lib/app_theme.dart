import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ColorScheme _darkScheme() => ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C5CE7),
    brightness: Brightness.dark,
    surface: const Color(0xFF0F1020),
  );

  static ColorScheme _lightScheme() => ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C5CE7),
    brightness: Brightness.light,
    surface: const Color(0xFFF5F7FF),
  );

  static ThemeData dark() {
    final colors = _darkScheme();
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0B0B16),
      textTheme: GoogleFonts.manropeTextTheme().apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white54),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static ThemeData light() {
    final colors = _lightScheme();
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.surface,
      textTheme: GoogleFonts.manropeTextTheme().apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary),
        ),
        labelStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
        hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static Gradient backgroundGradient(ColorScheme colors) {
    if (colors.brightness == Brightness.dark) {
      return const LinearGradient(
        colors: [Color(0xFF0D0F25), Color(0xFF1B1740)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return LinearGradient(
      colors: [colors.surface, colors.primary.withValues(alpha: 0.08)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static Color panelColor(ColorScheme colors) {
    return colors.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.05)
        : colors.surfaceContainerHighest;
  }

  static Color panelBorder(ColorScheme colors) {
    return colors.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : colors.outlineVariant.withValues(alpha: 0.6);
  }
}
