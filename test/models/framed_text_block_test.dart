import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/framed_text_block.dart';
import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';

StyledLine _line(String text) => StyledLine([StyledSpan(text: text)]);

void main() {
  group('stripFramedRowEdges', () {
    test('strips leading and trailing pipes, preserves interior spacing', () {
      final stripped = stripFramedRowEdges(
        _line('|     a dart.....................94      |'),
      );
      expect(
        stripped.plainText,
        '     a dart.....................94      ',
      );
    });

    test('handles trailing whitespace after the closing pipe', () {
      final stripped = stripFramedRowEdges(_line('| hello |   '));
      expect(stripped.plainText, ' hello ');
    });

    test('returns the line unchanged if it has no pipe edges', () {
      final stripped = stripFramedRowEdges(_line('plain text'));
      expect(stripped.plainText, 'plain text');
    });

    test('empty interior round-trips to an empty string', () {
      final stripped = stripFramedRowEdges(_line('||'));
      expect(stripped.plainText, '');
    });
  });

  group('FramedTextBlock', () {
    test('exposes line count', () {
      final block = FramedTextBlock([_line('a'), _line('b'), _line('c')]);
      expect(block.lineCount, 3);
    });
  });
}
