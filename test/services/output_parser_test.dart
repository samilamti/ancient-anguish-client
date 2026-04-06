import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/parser/output_parser.dart';

void main() {
  late OutputParser parser;

  setUp(() {
    parser = OutputParser();
  });

  group('OutputParser', () {
    test('splits input on newlines', () {
      final lines = parser.processText('Line 1\nLine 2\nLine 3\n');
      expect(lines, hasLength(3));
      expect(lines[0].plainText, 'Line 1');
      expect(lines[1].plainText, 'Line 2');
      expect(lines[2].plainText, 'Line 3');
    });

    test('handles CR+LF line endings', () {
      final lines = parser.processText('Hello\r\nWorld\r\n');
      expect(lines, hasLength(2));
      expect(lines[0].plainText, 'Hello');
      expect(lines[1].plainText, 'World');
    });

    test('buffers partial lines (no trailing newline)', () {
      final lines = parser.processText('partial');
      expect(lines, isEmpty);
      expect(parser.hasPendingData, true);
      expect(parser.pendingText, 'partial');
    });

    test('completes partial line when newline arrives', () {
      parser.processText('Hello ');
      final lines = parser.processText('World!\n');
      expect(lines, hasLength(1));
      expect(lines.first.plainText, 'Hello World!');
    });

    test('flush() emits partial line', () {
      parser.processText('prompt> ');
      final flushed = parser.flush();
      expect(flushed, isNotNull);
      expect(flushed!.plainText, 'prompt> ');
      expect(parser.hasPendingData, false);
    });

    test('flush() returns null when no pending data', () {
      expect(parser.flush(), isNull);
    });

    test('handles empty lines (consecutive newlines)', () {
      final lines = parser.processText('A\n\nB\n');
      expect(lines, hasLength(3));
      expect(lines[0].plainText, 'A');
      expect(lines[1].plainText, ''); // empty line
      expect(lines[2].plainText, 'B');
    });

    test('processBytes converts UTF-8 correctly', () {
      final bytes = utf8.encode('Héllo Wörld\n');
      final lines = parser.processBytes(bytes);
      expect(lines, hasLength(1));
      expect(lines.first.plainText, 'Héllo Wörld');
    });

    test('preserves ANSI styling within a line', () {
      final lines = parser.processText('\x1B[31mRed text\x1B[0m normal\n');
      expect(lines, hasLength(1));
      expect(lines.first.spans, hasLength(2));
      expect(lines.first.spans[0].text, 'Red text');
      expect(lines.first.spans[1].text, ' normal');
    });

    test('reset clears buffer and parser state', () {
      parser.processText('partial data');
      parser.reset();
      expect(parser.hasPendingData, false);
    });

    test('processBytes handles malformed UTF-8 without crashing', () {
      // Invalid UTF-8: continuation byte without start byte + newline
      final bytes = [0xC0, 0xAF, 0x0A];
      final lines = parser.processBytes(bytes);
      expect(lines, hasLength(1));
      // Should produce replacement chars rather than throwing
    });

    test('standalone CR is skipped', () {
      final lines = parser.processText('Hello\rWorld\n');
      expect(lines, hasLength(1));
      expect(lines.first.plainText, 'HelloWorld');
    });

    test('multiple consecutive flush calls return null after first', () {
      parser.processText('prompt');
      final first = parser.flush();
      expect(first, isNotNull);
      expect(first!.plainText, 'prompt');

      final second = parser.flush();
      expect(second, isNull);
    });

    test('interleaved processText and flush', () {
      parser.processText('part1');
      final lines = parser.processText(' part2\n');
      expect(lines, hasLength(1));
      expect(lines.first.plainText, 'part1 part2');

      parser.processText('pending');
      final flushed = parser.flush();
      expect(flushed!.plainText, 'pending');
    });
  });
}
