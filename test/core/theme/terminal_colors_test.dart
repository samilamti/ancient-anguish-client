import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/core/theme/terminal_colors.dart';

void main() {
  group('TerminalColors - ansi16', () {
    test('has exactly 16 entries', () {
      expect(TerminalColors.ansi16, hasLength(16));
    });

    test('first entry is black', () {
      expect(TerminalColors.ansi16[0], const Color(0xFF000000));
    });

    test('last entry is bright white', () {
      expect(TerminalColors.ansi16[15], const Color(0xFFFFFFFF));
    });

    test('index 8 is bright black (dark gray)', () {
      expect(TerminalColors.ansi16[8], const Color(0xFF555555));
    });
  });

  group('TerminalColors - fromAnsi256', () {
    test('indices 0-15 match ansi16 table', () {
      for (var i = 0; i < 16; i++) {
        expect(TerminalColors.fromAnsi256(i), TerminalColors.ansi16[i]);
      }
    });

    test('index 16 is black (0,0,0 in color cube)', () {
      expect(
        TerminalColors.fromAnsi256(16),
        const Color.fromARGB(255, 0, 0, 0),
      );
    });

    test('index 231 is white (5,5,5 in color cube)', () {
      // r=5, g=5, b=5 → 55 + 5*40 = 255 for each channel.
      expect(
        TerminalColors.fromAnsi256(231),
        const Color.fromARGB(255, 255, 255, 255),
      );
    });

    test('index 232 is darkest grayscale (8,8,8)', () {
      expect(
        TerminalColors.fromAnsi256(232),
        const Color.fromARGB(255, 8, 8, 8),
      );
    });

    test('index 255 is lightest grayscale (238,238,238)', () {
      // 8 + 23*10 = 238
      expect(
        TerminalColors.fromAnsi256(255),
        const Color.fromARGB(255, 238, 238, 238),
      );
    });

    test('color cube index 196 is bright red (r=5,g=0,b=0)', () {
      // index 196 = 16 + 180 → i=180 → r=180~/36=5, g=(180~/6)%6=0, b=180%6=0
      // r=5 → 55+5*40=255, g=0 → 0, b=0 → 0
      expect(
        TerminalColors.fromAnsi256(196),
        const Color.fromARGB(255, 255, 0, 0),
      );
    });

    test('color cube index 21 is bright blue (r=0,g=0,b=5)', () {
      // index 21 = 16 + 5 → i=5 → r=0, g=0, b=5
      // r=0 → 0, g=0 → 0, b=5 → 255
      expect(
        TerminalColors.fromAnsi256(21),
        const Color.fromARGB(255, 0, 0, 255),
      );
    });

    test('color cube mid-range index has correct values', () {
      // index 123 = 16 + 107 → i=107, r=107~/36=2, g=(107~/6)%6=5, b=107%6=5
      // r=2 → 55+80=135, g=5 → 255, b=5 → 255
      expect(
        TerminalColors.fromAnsi256(123),
        const Color.fromARGB(255, 135, 255, 255),
      );
    });
  });

  group('TerminalColors - fromSgrForeground', () {
    test('code 30 returns black', () {
      expect(
        TerminalColors.fromSgrForeground(30),
        TerminalColors.black,
      );
    });

    test('code 37 returns white (light gray)', () {
      expect(
        TerminalColors.fromSgrForeground(37),
        TerminalColors.white,
      );
    });

    test('code 31 with bold returns bright red', () {
      expect(
        TerminalColors.fromSgrForeground(31, bold: true),
        TerminalColors.brightRed,
      );
    });

    test('code 31 without bold returns normal red', () {
      expect(
        TerminalColors.fromSgrForeground(31),
        TerminalColors.red,
      );
    });

    test('codes 90-97 return bright colors', () {
      expect(TerminalColors.fromSgrForeground(90), TerminalColors.brightBlack);
      expect(TerminalColors.fromSgrForeground(91), TerminalColors.brightRed);
      expect(TerminalColors.fromSgrForeground(97), TerminalColors.brightWhite);
    });

    test('invalid code returns null', () {
      expect(TerminalColors.fromSgrForeground(0), isNull);
      expect(TerminalColors.fromSgrForeground(29), isNull);
      expect(TerminalColors.fromSgrForeground(38), isNull);
      expect(TerminalColors.fromSgrForeground(89), isNull);
      expect(TerminalColors.fromSgrForeground(98), isNull);
    });
  });

  group('TerminalColors - fromSgrBackground', () {
    test('code 40 returns black', () {
      expect(TerminalColors.fromSgrBackground(40), TerminalColors.black);
    });

    test('code 47 returns white (light gray)', () {
      expect(TerminalColors.fromSgrBackground(47), TerminalColors.white);
    });

    test('code 100 returns bright black', () {
      expect(
        TerminalColors.fromSgrBackground(100),
        TerminalColors.brightBlack,
      );
    });

    test('code 107 returns bright white', () {
      expect(
        TerminalColors.fromSgrBackground(107),
        TerminalColors.brightWhite,
      );
    });

    test('invalid code returns null', () {
      expect(TerminalColors.fromSgrBackground(0), isNull);
      expect(TerminalColors.fromSgrBackground(39), isNull);
      expect(TerminalColors.fromSgrBackground(48), isNull);
      expect(TerminalColors.fromSgrBackground(99), isNull);
      expect(TerminalColors.fromSgrBackground(108), isNull);
    });
  });
}
