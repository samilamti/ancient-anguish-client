import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/core/theme/terminal_colors.dart';
import 'package:ancient_anguish_client/protocol/ansi/ansi_parser.dart';

void main() {
  late AnsiParser parser;

  setUp(() {
    parser = AnsiParser();
  });

  group('AnsiParser', () {
    test('parses plain text without escape sequences', () {
      final spans = parser.parse('Hello, World!');
      expect(spans, hasLength(1));
      expect(spans.first.text, 'Hello, World!');
      expect(spans.first.foreground, TerminalColors.defaultForeground);
      expect(spans.first.bold, false);
    });

    test('parses reset code (ESC[0m)', () {
      final spans = parser.parse('\x1B[1mBold\x1B[0mNormal');
      expect(spans, hasLength(2));
      expect(spans[0].text, 'Bold');
      expect(spans[0].bold, true);
      expect(spans[1].text, 'Normal');
      expect(spans[1].bold, false);
    });

    test('parses bold attribute (ESC[1m)', () {
      final spans = parser.parse('\x1B[1mBold text');
      expect(spans, hasLength(1));
      expect(spans.first.text, 'Bold text');
      expect(spans.first.bold, true);
    });

    test('parses italic attribute (ESC[3m)', () {
      final spans = parser.parse('\x1B[3mItalic text');
      expect(spans, hasLength(1));
      expect(spans.first.italic, true);
    });

    test('parses underline attribute (ESC[4m)', () {
      final spans = parser.parse('\x1B[4mUnderlined');
      expect(spans, hasLength(1));
      expect(spans.first.underline, true);
    });

    test('parses strikethrough attribute (ESC[9m)', () {
      final spans = parser.parse('\x1B[9mStrikethrough');
      expect(spans, hasLength(1));
      expect(spans.first.strikethrough, true);
    });

    test('parses standard 16 foreground colors', () {
      // Red foreground (31)
      final spans = parser.parse('\x1B[31mRed text');
      expect(spans, hasLength(1));
      expect(spans.first.text, 'Red text');
      expect(spans.first.foreground, TerminalColors.red);
    });

    test('parses bright foreground colors (90-97)', () {
      // Bright green (92)
      final spans = parser.parse('\x1B[92mBright green');
      expect(spans, hasLength(1));
      expect(spans.first.foreground, TerminalColors.brightGreen);
    });

    test('parses standard background colors (40-47)', () {
      final spans = parser.parse('\x1B[44mBlue background');
      expect(spans, hasLength(1));
      expect(spans.first.background, TerminalColors.blue);
    });

    test('parses combined attributes', () {
      // Bold + red foreground: ESC[1;31m
      final spans = parser.parse('\x1B[1;31mBold red');
      expect(spans, hasLength(1));
      expect(spans.first.bold, true);
      // Bold promotes red to bright red on standard terminals.
      expect(spans.first.foreground, TerminalColors.brightRed);
    });

    test('parses 256-color foreground (ESC[38;5;nm)', () {
      // Color index 196 (bright red in 256-color palette)
      final spans = parser.parse('\x1B[38;5;196mCustom red');
      expect(spans, hasLength(1));
      expect(spans.first.foreground, TerminalColors.fromAnsi256(196));
    });

    test('parses 256-color background (ESC[48;5;nm)', () {
      final spans = parser.parse('\x1B[48;5;21mBlue bg');
      expect(spans, hasLength(1));
      expect(spans.first.background, TerminalColors.fromAnsi256(21));
    });

    test('parses truecolor foreground (ESC[38;2;r;g;bm)', () {
      final spans = parser.parse('\x1B[38;2;255;128;0mOrange');
      expect(spans, hasLength(1));
      expect(spans.first.foreground, const Color.fromARGB(255, 255, 128, 0));
    });

    test('parses truecolor background (ESC[48;2;r;g;bm)', () {
      final spans = parser.parse('\x1B[48;2;0;0;128mDark blue bg');
      expect(spans, hasLength(1));
      expect(spans.first.background, const Color.fromARGB(255, 0, 0, 128));
    });

    test('parses inverse video (ESC[7m)', () {
      parser.parse('\x1B[31m'); // Set red foreground
      final spans = parser.parse('\x1B[7mInverted');
      expect(spans, hasLength(1));
      // Inverse: foreground becomes background color, background becomes foreground.
      expect(spans.first.foreground, TerminalColors.defaultBackground);
      expect(spans.first.background, TerminalColors.red);
    });

    test('handles multiple style changes in one line', () {
      final spans = parser.parse(
        'Normal \x1B[31mRed \x1B[1mBold Red \x1B[0mBack to normal',
      );
      expect(spans, hasLength(4));
      expect(spans[0].text, 'Normal ');
      expect(spans[1].text, 'Red ');
      expect(spans[1].foreground, TerminalColors.red);
      expect(spans[2].text, 'Bold Red ');
      expect(spans[2].bold, true);
      expect(spans[3].text, 'Back to normal');
      expect(spans[3].bold, false);
    });

    test('preserves state across multiple parse calls (streaming)', () {
      // First chunk sets bold.
      parser.parse('\x1B[1m');
      // Second chunk should inherit bold.
      final spans = parser.parse('Still bold');
      expect(spans, hasLength(1));
      expect(spans.first.bold, true);
    });

    test('handles empty ESC[m as reset', () {
      parser.parse('\x1B[1m');
      final spans = parser.parse('\x1B[mNormal');
      expect(spans, hasLength(1));
      expect(spans.first.bold, false);
    });

    test('reset() clears all style state', () {
      parser.parse('\x1B[1;31;4m'); // Bold, red, underline
      parser.reset();
      final spans = parser.parse('After reset');
      expect(spans, hasLength(1));
      expect(spans.first.bold, false);
      expect(spans.first.underline, false);
      expect(spans.first.foreground, TerminalColors.defaultForeground);
    });

    test('handles default foreground reset (ESC[39m)', () {
      parser.parse('\x1B[31m'); // Red
      final spans = parser.parse('\x1B[39mDefault');
      expect(spans, hasLength(1));
      expect(spans.first.foreground, TerminalColors.defaultForeground);
    });

    test('handles default background reset (ESC[49m)', () {
      parser.parse('\x1B[44m'); // Blue bg
      final spans = parser.parse('\x1B[49mDefault bg');
      expect(spans, hasLength(1));
      expect(spans.first.background, TerminalColors.defaultBackground);
    });

    test('ignores non-SGR CSI sequences', () {
      // ESC[2J is clear screen – should be ignored, not crash.
      final spans = parser.parse('\x1B[2JVisible text');
      expect(spans, hasLength(1));
      expect(spans.first.text, 'Visible text');
    });
  });

  group('TerminalColors', () {
    test('ansi256 palette has 256 entries', () {
      expect(TerminalColors.ansi256, hasLength(256));
    });

    test('first 16 ansi256 entries match ansi16', () {
      for (var i = 0; i < 16; i++) {
        expect(TerminalColors.ansi256[i], TerminalColors.ansi16[i]);
      }
    });

    test('grayscale ramp has correct first and last entries', () {
      // Index 232 should be (8, 8, 8).
      expect(TerminalColors.ansi256[232], const Color.fromARGB(255, 8, 8, 8));
      // Index 255 should be (238, 238, 238).
      expect(
          TerminalColors.ansi256[255], const Color.fromARGB(255, 238, 238, 238));
    });
  });
}
