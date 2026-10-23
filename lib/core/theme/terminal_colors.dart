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
  static const Color blue = Color(0xFF5C5CFF);
  static const Color magenta = Color(0xFFAA00AA);
  static const Color cyan = Color(0xFF00AAAA);
  static const Color white = Color(0xFFAAAAAA);

  static const Color brightBlack = Color(0xFF555555);
  static const Color brightRed = Color(0xFFFF5555);
  static const Color brightGreen = Color(0xFF55FF55);
  static const Color brightYellow = Color(0xFFFFFF55);
  static const Color brightBlue = Color(0xFF7A7AFF);
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

  // ── Paper (light theme) ──

  /// The light theme's page colour: a warm off-white, like a word processor.
  static const Color paper = Color(0xFFFAF9F5);

  /// The light theme's default text colour: near-black, slightly warm.
  static const Color ink = Color(0xFF1F1E1D);

  /// The 16 ANSI colours re-cut for [paper]. MUD colours are chosen for a
  /// black screen, so yellow, cyan, white and the bright set all wash out on
  /// a light page. Each entry keeps its hue and clears 4.5:1 against [paper]
  /// (pinned by `terminal_colors_test.dart`).
  static const List<Color> paperAnsi16 = [
    ink, // black
    Color(0xFFB3261E), // red
    Color(0xFF2E7D32), // green
    Color(0xFF8A5A00), // yellow
    Color(0xFF3949AB), // blue
    Color(0xFF8E24AA), // magenta
    Color(0xFF00737A), // cyan
    Color(0xFF5F5E5A), // white (MUDs use it as ordinary grey text)
    Color(0xFF6B6963), // bright black
    Color(0xFFC62828), // bright red
    Color(0xFF1B7A35), // bright green
    Color(0xFF946200), // bright yellow
    Color(0xFF2F55C8), // bright blue
    Color(0xFFA3239E), // bright magenta
    Color(0xFF007C85), // bright cyan
    Color(0xFF000000), // bright white (emphasis, so darker than ink)
  ];

  /// Maps a colour meant for the dark terminal onto [paper].
  ///
  /// Terminal lines store concrete colours, so the light theme remaps at
  /// render time: the defaults swap to [ink]/[paper], the ANSI 16 use
  /// [paperAnsi16], and anything else (256-colour, trigger highlights, link
  /// blues) is darkened until it reads at 4.5:1.
  static Color onPaper(Color c) {
    if (c == defaultForeground) return ink;
    if (c == defaultBackground) return paper;
    final i = ansi16.indexOf(c);
    if (i >= 0) return paperAnsi16[i];
    return legibleOn(paper, c);
  }

  /// Darkens [c] toward [ink] until it reaches [ratio] against [ground].
  static Color legibleOn(Color ground, Color c, {double ratio = 4.5}) {
    var out = c.withAlpha(255);
    for (var step = 0; step <= 20; step++) {
      // Quantise before measuring, so the 8-bit result is the one that passes.
      out = Color.lerp(c.withAlpha(255), ink, step / 20)!.withAlpha(255);
      if (contrast(out, ground) >= ratio) break;
    }
    return out.withAlpha((c.a * 255).round());
  }

  /// WCAG contrast ratio between two opaque colours.
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

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
