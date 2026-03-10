import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/parser/output_parser.dart';

/// Tests for prompt detection using @@...@@ markers.
///
/// The MUD prompt is decorated with @@ prefix and suffix:
///   prompt set @@|HP| |MAXHP| |SP| |MAXSP| |XCOORD| |YCOORD|@@
///
/// Server output: @@154 154 170 170 0 0@@ (with ANSI codes around numbers).
/// The markers make detection reliable in all delivery scenarios:
///   1. Pending buffer (prompt without newline, consumed before next data)
///   2. GA-terminated line (if server sends GA despite SGA)
///   3. Prepended to next line (fallback: prompt + game text on one line)
void main() {
  late OutputParser parser;

  final promptRegex = RegExp(
      r'@@\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(-?\d+)\s+(-?\d+)@@');
  final ansiEscapeRegex = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');

  setUp(() {
    parser = OutputParser();
  });

  /// Simulates the connection provider's pending buffer check.
  bool checkAndConsumePrompt(OutputParser parser) {
    if (!parser.hasPendingData) return false;
    final pendingPlain =
        parser.pendingText.replaceAll(ansiEscapeRegex, '');
    if (!promptRegex.hasMatch(pendingPlain)) return false;
    parser.flush();
    return true;
  }

  group('Pending buffer detection', () {
    test('detects plain prompt in pending buffer', () {
      final lines = parser.processText('Room description\n@@154 154 170 170 0 0@@');
      expect(lines, hasLength(1));
      expect(lines.first.plainText, 'Room description');
      expect(parser.hasPendingData, true);
      expect(checkAndConsumePrompt(parser), true);
      expect(parser.hasPendingData, false);
    });

    test('detects ANSI-colored prompt in pending buffer', () {
      final ansiPrompt =
          '@@\x1B[32m154\x1B[0m \x1B[32m154\x1B[0m \x1B[31m 10\x1B[0m \x1B[32m170\x1B[0m \x1B[0m0\x1B[0m \x1B[0m0\x1B[0m@@';
      parser.processText('Some output\n$ansiPrompt');
      expect(parser.hasPendingData, true);
      expect(checkAndConsumePrompt(parser), true);
      expect(parser.hasPendingData, false);
    });

    test('does not consume non-prompt pending data', () {
      parser.processText('What is your name: ');
      expect(checkAndConsumePrompt(parser), false);
      expect(parser.hasPendingData, true);
    });

    test('does not consume text without @@ markers', () {
      parser.processText('154 154 170 170 0 0 ');
      expect(checkAndConsumePrompt(parser), false);
    });
  });

  group('Prepended prompt detection (fallback)', () {
    test('regex matches prompt at start of line', () {
      const text = '@@154 154 170 170 0 0@@Room description here';
      final match = promptRegex.firstMatch(text);
      expect(match, isNotNull);
      expect(match!.group(1), '154');
      expect(match.group(6), '0');
      final remainder = text.substring(match.end).trim();
      expect(remainder, 'Room description here');
    });

    test('regex matches prompt as entire line', () {
      const text = '@@154 154 170 170 0 0@@';
      final match = promptRegex.firstMatch(text);
      expect(match, isNotNull);
      final remainder = text.substring(match!.end).trim();
      expect(remainder, isEmpty);
    });

    test('without flush, prompt markers prepend to next line', () {
      parser.processText('Room desc\n@@154 154 170 170 0 0@@');
      // Don't consume. Next data arrives.
      final lines = parser.processText('You go north.\n');
      expect(lines, hasLength(1));
      expect(lines.first.plainText, contains('@@154 154'));
      expect(lines.first.plainText, contains('You go north.'));
      // Regex can still find the prompt in the combined line.
      final match = promptRegex.firstMatch(lines.first.plainText);
      expect(match, isNotNull);
    });

    test('with flush, next line is clean', () {
      parser.processText('Room desc\n@@154 154 170 170 0 0@@');
      expect(checkAndConsumePrompt(parser), true);
      final lines = parser.processText('You go north.\n');
      expect(lines, hasLength(1));
      expect(lines.first.plainText, 'You go north.');
    });
  });

  group('Regex edge cases', () {
    test('handles negative coordinates', () {
      final match = promptRegex.firstMatch('@@100 100 50 50 -5 -10@@');
      expect(match, isNotNull);
      expect(match!.group(5), '-5');
      expect(match.group(6), '-10');
    });

    test('handles large values', () {
      final match = promptRegex.firstMatch('@@1500 1500 800 800 25 -12@@');
      expect(match, isNotNull);
    });

    test('handles multiple spaces between numbers', () {
      final match = promptRegex.firstMatch('@@  50   50    4   50   0   0@@');
      expect(match, isNotNull);
      expect(match!.group(1), '50');
      expect(match.group(3), '4');
    });

    test('does not match without @@ markers', () {
      final match = promptRegex.firstMatch('154 154 170 170 0 0');
      expect(match, isNull);
    });

    test('does not match with only prefix', () {
      final match = promptRegex.firstMatch('@@154 154 170 170 0 0');
      expect(match, isNull);
    });

    test('flushed StyledLine preserves ANSI-stripped values', () {
      final ansiPrompt =
          '@@\x1B[32m 50\x1B[0m \x1B[32m 50\x1B[0m \x1B[31m  4\x1B[0m \x1B[32m 50\x1B[0m \x1B[0m0\x1B[0m \x1B[0m0\x1B[0m@@';
      parser.processText(ansiPrompt);
      final flushed = parser.flush()!;
      final match = promptRegex.firstMatch(flushed.plainText);
      expect(match, isNotNull);
      expect(match!.group(1), '50');
      expect(match.group(3), '4');
      expect(match.group(5), '0');
    });
  });
}
