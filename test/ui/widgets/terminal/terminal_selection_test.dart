import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/terminal_selection.dart';

void main() {
  group('TerminalPosition', () {
    test('compares by line first, then column', () {
      const a = TerminalPosition(0, 5);
      const b = TerminalPosition(1, 0);
      const c = TerminalPosition(1, 3);

      expect(a < b, isTrue);
      expect(b < c, isTrue);
      expect(a < c, isTrue);
      expect(c > a, isTrue);
    });

    test('equality works', () {
      const a = TerminalPosition(2, 4);
      const b = TerminalPosition(2, 4);
      const c = TerminalPosition(2, 5);

      expect(a == b, isTrue);
      expect(a == c, isFalse);
      expect(a.hashCode == b.hashCode, isTrue);
    });

    test('<= and >= work for equal positions', () {
      const a = TerminalPosition(1, 1);
      const b = TerminalPosition(1, 1);
      expect(a <= b, isTrue);
      expect(a >= b, isTrue);
    });
  });

  group('TerminalSelection', () {
    test('start and end are normalized', () {
      const sel = TerminalSelection(
        anchor: TerminalPosition(3, 5),
        focus: TerminalPosition(1, 2),
      );
      expect(sel.start, const TerminalPosition(1, 2));
      expect(sel.end, const TerminalPosition(3, 5));
    });

    test('start and end when anchor < focus', () {
      const sel = TerminalSelection(
        anchor: TerminalPosition(0, 0),
        focus: TerminalPosition(2, 3),
      );
      expect(sel.start, const TerminalPosition(0, 0));
      expect(sel.end, const TerminalPosition(2, 3));
    });

    group('containsLine', () {
      const sel = TerminalSelection(
        anchor: TerminalPosition(2, 3),
        focus: TerminalPosition(5, 7),
      );

      test('returns true for lines within range', () {
        expect(sel.containsLine(2), isTrue);
        expect(sel.containsLine(3), isTrue);
        expect(sel.containsLine(5), isTrue);
      });

      test('returns false for lines outside range', () {
        expect(sel.containsLine(1), isFalse);
        expect(sel.containsLine(6), isFalse);
      });
    });

    group('selectedRangeForLine', () {
      const sel = TerminalSelection(
        anchor: TerminalPosition(1, 5),
        focus: TerminalPosition(3, 8),
      );

      test('returns null for line outside selection', () {
        expect(sel.selectedRangeForLine(0, 20), isNull);
        expect(sel.selectedRangeForLine(4, 20), isNull);
      });

      test('returns partial range for start line', () {
        final range = sel.selectedRangeForLine(1, 20);
        expect(range, isNotNull);
        expect(range!.startCol, 5);
        expect(range.endCol, 20); // full to end
      });

      test('returns full range for middle line', () {
        final range = sel.selectedRangeForLine(2, 15);
        expect(range, isNotNull);
        expect(range!.startCol, 0);
        expect(range.endCol, 15);
      });

      test('returns partial range for end line', () {
        final range = sel.selectedRangeForLine(3, 20);
        expect(range, isNotNull);
        expect(range!.startCol, 0);
        expect(range.endCol, 8);
      });
    });

    group('selectedRangeForLine on single-line selection', () {
      const sel = TerminalSelection(
        anchor: TerminalPosition(2, 3),
        focus: TerminalPosition(2, 10),
      );

      test('returns exact range for the single line', () {
        final range = sel.selectedRangeForLine(2, 20);
        expect(range, isNotNull);
        expect(range!.startCol, 3);
        expect(range.endCol, 10);
      });
    });

    group('extractText', () {
      final lines = [
        StyledLine([StyledSpan(text: 'Hello World')]),
        StyledLine([StyledSpan(text: 'Foo Bar Baz')]),
        StyledLine([StyledSpan(text: 'End of text')]),
      ];

      test('extracts single-line partial selection', () {
        const sel = TerminalSelection(
          anchor: TerminalPosition(0, 6),
          focus: TerminalPosition(0, 11),
        );
        expect(sel.extractText(lines), 'World');
      });

      test('extracts multi-line selection', () {
        const sel = TerminalSelection(
          anchor: TerminalPosition(0, 6),
          focus: TerminalPosition(1, 3),
        );
        expect(sel.extractText(lines), 'World\nFoo');
      });

      test('extracts full buffer', () {
        const sel = TerminalSelection(
          anchor: TerminalPosition(0, 0),
          focus: TerminalPosition(2, 11),
        );
        expect(sel.extractText(lines),
            'Hello World\nFoo Bar Baz\nEnd of text');
      });

      test('clamps out-of-range columns', () {
        const sel = TerminalSelection(
          anchor: TerminalPosition(0, 0),
          focus: TerminalPosition(0, 999),
        );
        expect(sel.extractText(lines), 'Hello World');
      });

      test('handles reversed anchor/focus', () {
        const sel = TerminalSelection(
          anchor: TerminalPosition(1, 4),
          focus: TerminalPosition(0, 0),
        );
        expect(sel.extractText(lines), 'Hello World\nFoo ');
      });

      test('handles empty lines', () {
        final linesWithEmpty = [
          StyledLine([StyledSpan(text: 'Line 1')]),
          StyledLine.empty(),
          StyledLine([StyledSpan(text: 'Line 3')]),
        ];
        const sel = TerminalSelection(
          anchor: TerminalPosition(0, 0),
          focus: TerminalPosition(2, 6),
        );
        expect(sel.extractText(linesWithEmpty), 'Line 1\n\nLine 3');
      });
    });

    test('equality works', () {
      const a = TerminalSelection(
        anchor: TerminalPosition(0, 0),
        focus: TerminalPosition(1, 5),
      );
      const b = TerminalSelection(
        anchor: TerminalPosition(0, 0),
        focus: TerminalPosition(1, 5),
      );
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
    });
  });
}
