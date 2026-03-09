import 'package:flutter/material.dart';
import 'terminal_colors.dart';

/// RPG-themed application themes for the Ancient Anguish client.
class AppTheme {
  AppTheme._();

  // ── Color tokens ──

  static const Color _gold = Color(0xFFD4A057);
  static const Color _saddleBrown = Color(0xFF8B4513);
  static const Color _darkWood = Color(0xFF2A1810);
  static const Color _parchment = Color(0xFFE8D5B7);
  /// The primary RPG dark theme.
  static ThemeData rpgDark() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: TerminalColors.defaultBackground,
      colorScheme: const ColorScheme.dark(
        primary: _gold,
        secondary: _saddleBrown,
        surface: _darkWood,
        onSurface: _parchment,
        error: TerminalColors.brightRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkWood,
        foregroundColor: _gold,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _darkWood.withAlpha(200),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: _gold.withAlpha(60)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0D0D1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _gold.withAlpha(80)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _gold, width: 2),
        ),
        hintStyle: TextStyle(color: _parchment.withAlpha(100)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _saddleBrown,
          foregroundColor: _parchment,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: _parchment),
        bodyMedium: TextStyle(color: _parchment),
        titleLarge: TextStyle(
          color: _gold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Classic dark terminal theme – minimal decoration.
  static ThemeData classicDark() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF000000),
      colorScheme: const ColorScheme.dark(
        primary: TerminalColors.brightGreen,
        secondary: TerminalColors.cyan,
        surface: Color(0xFF111111),
      ),
    );
  }

  /// High-contrast accessibility theme.
  static ThemeData highContrast() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF000000),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFFF00),
        secondary: Color(0xFF00FFFF),
        surface: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 18, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }
}
