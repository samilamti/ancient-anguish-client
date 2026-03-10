import 'dart:ui';

import '../../core/theme/terminal_colors.dart';
import 'styled_span.dart';

/// Parses ANSI escape sequences from decoded text and produces a list of
/// [StyledSpan] objects suitable for rendering in Flutter [RichText] widgets.
///
/// Supports:
/// - SGR (Select Graphic Rendition) for colors and attributes.
/// - 16-color standard (codes 30-37, 40-47, 90-97, 100-107).
/// - 256-color extended (38;5;n / 48;5;n).
/// - 24-bit truecolor (38;2;r;g;b / 48;2;r;g;b).
/// - Bold, italic, underline, strikethrough, inverse.
/// - Reset (code 0).
class AnsiParser {
  // Current style state – persistent across calls for streaming input.
  Color _fg = TerminalColors.defaultForeground;
  Color _bg = TerminalColors.defaultBackground;
  bool _bold = false;
  bool _italic = false;
  bool _underline = false;
  bool _strikethrough = false;
  bool _inverse = false;
  bool _dim = false;

  /// Parses [input] text containing ANSI escape sequences.
  ///
  /// Returns a list of [StyledSpan]s representing styled text segments.
  /// Style state is preserved between calls for streaming data.
  List<StyledSpan> parse(String input) {
    final spans = <StyledSpan>[];
    final buffer = StringBuffer();
    var i = 0;

    while (i < input.length) {
      // Check for ESC character (0x1B).
      if (input.codeUnitAt(i) == 0x1B && i + 1 < input.length) {
        if (input.codeUnitAt(i + 1) == 0x5B) {
          // ESC[ – CSI sequence.
          // Flush current buffer as a span with current style.
          _flushBuffer(buffer, spans);

          // Parse CSI parameters.
          i += 2; // skip ESC[
          final paramStart = i;

          // Collect parameter bytes (0x30-0x3F) and intermediate bytes (0x20-0x2F).
          while (i < input.length) {
            final c = input.codeUnitAt(i);
            if (c >= 0x40 && c <= 0x7E) break; // final byte
            i++;
          }

          if (i < input.length) {
            final finalByte = input.codeUnitAt(i);
            final paramStr = input.substring(paramStart, i);
            i++; // consume final byte

            if (finalByte == 0x6D) {
              // 'm' – SGR command
              _applySgr(paramStr);
            }
            // Other CSI commands (cursor movement, etc.) are ignored for MUD output.
          }
          continue;
        } else {
          // Other escape sequences (ESC], etc.) – skip ESC and continue.
          i++;
          continue;
        }
      }

      // Regular character.
      buffer.writeCharCode(input.codeUnitAt(i));
      i++;
    }

    // Flush remaining text.
    _flushBuffer(buffer, spans);
    return spans;
  }

  /// Resets the parser to default style state.
  void reset() {
    _fg = TerminalColors.defaultForeground;
    _bg = TerminalColors.defaultBackground;
    _bold = false;
    _italic = false;
    _underline = false;
    _strikethrough = false;
    _inverse = false;
    _dim = false;
  }

  // ── Private ──

  void _flushBuffer(StringBuffer buffer, List<StyledSpan> spans) {
    if (buffer.isEmpty) return;

    // Apply inverse: swap fg/bg if active.
    final fg = _inverse ? _bg : _fg;
    final bg = _inverse ? _fg : _bg;

    // Apply dim: reduce foreground brightness by ~50%.
    final effectiveFg = _dim ? _dimColor(fg) : fg;

    spans.add(StyledSpan(
      text: buffer.toString(),
      foreground: effectiveFg,
      background: bg,
      bold: _bold,
      italic: _italic,
      underline: _underline,
      strikethrough: _strikethrough,
    ));
    buffer.clear();
  }

  /// Applies SGR parameter string (e.g., "1;31" for bold red).
  void _applySgr(String paramStr) {
    if (paramStr.isEmpty) {
      _reset();
      return;
    }

    final params = paramStr.split(';').map((s) => int.tryParse(s) ?? 0).toList();

    var i = 0;
    while (i < params.length) {
      final code = params[i];
      switch (code) {
        case 0:
          _reset();
        case 1:
          _bold = true;
        case 2:
          _dim = true;
        case 3:
          _italic = true;
        case 4:
          _underline = true;
        case 7:
          _inverse = true;
        case 9:
          _strikethrough = true;
        case 21:
          _bold = false; // Some terminals use 21 to disable bold.
        case 22:
          _bold = false;
          _dim = false;
        case 23:
          _italic = false;
        case 24:
          _underline = false;
        case 27:
          _inverse = false;
        case 29:
          _strikethrough = false;

        // Foreground colors 30-37.
        case >= 30 && <= 37:
          _fg = TerminalColors.fromSgrForeground(code, bold: _bold) ??
              TerminalColors.defaultForeground;

        // Extended foreground: 38;5;n (256-color) or 38;2;r;g;b (truecolor).
        case 38:
          i++;
          if (i < params.length) {
            if (params[i] == 5 && i + 1 < params.length) {
              // 256-color
              i++;
              _fg = TerminalColors.fromAnsi256(params[i].clamp(0, 255));
            } else if (params[i] == 2 && i + 3 < params.length) {
              // Truecolor
              final r = params[i + 1].clamp(0, 255);
              final g = params[i + 2].clamp(0, 255);
              final b = params[i + 3].clamp(0, 255);
              _fg = Color.fromARGB(255, r, g, b);
              i += 3;
            }
          }

        // Default foreground.
        case 39:
          _fg = TerminalColors.defaultForeground;

        // Background colors 40-47.
        case >= 40 && <= 47:
          _bg = TerminalColors.fromSgrBackground(code) ??
              TerminalColors.defaultBackground;

        // Extended background: 48;5;n or 48;2;r;g;b.
        case 48:
          i++;
          if (i < params.length) {
            if (params[i] == 5 && i + 1 < params.length) {
              i++;
              _bg = TerminalColors.fromAnsi256(params[i].clamp(0, 255));
            } else if (params[i] == 2 && i + 3 < params.length) {
              final r = params[i + 1].clamp(0, 255);
              final g = params[i + 2].clamp(0, 255);
              final b = params[i + 3].clamp(0, 255);
              _bg = Color.fromARGB(255, r, g, b);
              i += 3;
            }
          }

        // Default background.
        case 49:
          _bg = TerminalColors.defaultBackground;

        // Bright foreground colors 90-97.
        case >= 90 && <= 97:
          _fg = TerminalColors.fromSgrForeground(code) ??
              TerminalColors.defaultForeground;

        // Bright background colors 100-107.
        case >= 100 && <= 107:
          _bg = TerminalColors.fromSgrBackground(code) ??
              TerminalColors.defaultBackground;
      }
      i++;
    }
  }

  void _reset() {
    _fg = TerminalColors.defaultForeground;
    _bg = TerminalColors.defaultBackground;
    _bold = false;
    _italic = false;
    _underline = false;
    _strikethrough = false;
    _inverse = false;
    _dim = false;
  }

  /// Dims a color by reducing its brightness by ~50%.
  Color _dimColor(Color c) {
    return Color.fromARGB(
      c.a.toInt(),
      (c.r * 0.5).toInt(),
      (c.g * 0.5).toInt(),
      (c.b * 0.5).toInt(),
    );
  }
}
