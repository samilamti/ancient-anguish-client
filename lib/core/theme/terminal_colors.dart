import 'dart:ui';

/// ANSI color palette mapping for terminal rendering.
///
/// Provides the standard 16-color ANSI palette, the 256-color extended palette,
/// and utilities for mapping ANSI SGR codes to Flutter [Color] values.
class TerminalColors {
  TerminalColors._();

  // ── Standard 16 ANSI colors (0-7 normal, 8-15 bright) ──

  static const Color black = Color(0xFF000000);
  static const Color red = Color(0xFFAA0000);
  static const Color green = Color(0xFF00AA00);
  static const Color yellow = Color(0xFFAA5500);
  static const Color blue = Color(0xFF0000AA);
  static const Color magenta = Color(0xFFAA00AA);
  static const Color cyan = Color(0xFF00AAAA);
  static const Color white = Color(0xFFAAAAAA);

  static const Color brightBlack = Color(0xFF555555);
  static const Color brightRed = Color(0xFFFF5555);
  static const Color brightGreen = Color(0xFF55FF55);
  static const Color brightYellow = Color(0xFFFFFF55);
  static const Color brightBlue = Color(0xFF5555FF);
  static const Color brightMagenta = Color(0xFFFF55FF);
  static const Color brightCyan = Color(0xFF55FFFF);
  static const Color brightWhite = Color(0xFFFFFFFF);

  /// The default foreground color (light gray).
  static const Color defaultForeground = Color(0xFFCCCCCC);

  /// The default background color (near-black).
  static const Color defaultBackground = Color(0xFF1A1A2E);

  /// Standard 16-color lookup table indexed by ANSI color number (0-15).
  static const List<Color> ansi16 = [
    black, red, green, yellow, blue, magenta, cyan, white,
    brightBlack, brightRed, brightGreen, brightYellow,
    brightBlue, brightMagenta, brightCyan, brightWhite,
  ];

  /// Lazily-built 256-color palette.
  static final List<Color> ansi256 = _buildAnsi256();

  /// Returns the [Color] for a given ANSI 256-color index.
  static Color fromAnsi256(int index) {
    assert(index >= 0 && index < 256);
    return ansi256[index];
  }

  /// Returns the [Color] for a standard ANSI foreground code (30-37, 90-97).
  static Color? fromSgrForeground(int code, {bool bold = false}) {
    if (code >= 30 && code <= 37) {
      final index = code - 30;
      // Bold promotes normal colors to bright on many terminals.
      return bold ? ansi16[index + 8] : ansi16[index];
    }
    if (code >= 90 && code <= 97) {
      return ansi16[code - 90 + 8];
    }
    return null;
  }

  /// Returns the [Color] for a standard ANSI background code (40-47, 100-107).
  static Color? fromSgrBackground(int code) {
    if (code >= 40 && code <= 47) return ansi16[code - 40];
    if (code >= 100 && code <= 107) return ansi16[code - 100 + 8];
    return null;
  }

  // ── Private ──

  /// Builds the full 256-color palette:
  ///   0-15:    Standard 16 colors
  ///   16-231:  6x6x6 color cube
  ///   232-255: Grayscale ramp
  static List<Color> _buildAnsi256() {
    final palette = List<Color>.filled(256, black);

    // 0-15: standard colors
    for (var i = 0; i < 16; i++) {
      palette[i] = ansi16[i];
    }

    // 16-231: 6x6x6 color cube
    for (var i = 0; i < 216; i++) {
      final r = (i ~/ 36) % 6;
      final g = (i ~/ 6) % 6;
      final b = i % 6;
      palette[16 + i] = Color.fromARGB(
        255,
        r == 0 ? 0 : 55 + r * 40,
        g == 0 ? 0 : 55 + g * 40,
        b == 0 ? 0 : 55 + b * 40,
      );
    }

    // 232-255: grayscale ramp (8 to 238 in steps of 10)
    for (var i = 0; i < 24; i++) {
      final v = 8 + i * 10;
      palette[232 + i] = Color.fromARGB(255, v, v, v);
    }

    return palette;
  }
}
