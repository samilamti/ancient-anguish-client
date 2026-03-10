import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/core/theme/terminal_colors.dart';
import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';

void main() {
  group('StyledSpan', () {
    test('default constructor has expected defaults', () {
      const span = StyledSpan(text: 'hello');
      expect(span.text, 'hello');
      expect(span.foreground, TerminalColors.defaultForeground);
      expect(span.background, TerminalColors.defaultBackground);
      expect(span.bold, false);
      expect(span.italic, false);
      expect(span.underline, false);
      expect(span.strikethrough, false);
    });

    test('toTextSpan with default styling', () {
      const span = StyledSpan(text: 'normal');
      final ts = span.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      expect(ts.text, 'normal');
      expect(ts.style!.fontFamily, 'Mono');
      expect(ts.style!.fontSize, 14.0);
      expect(ts.style!.color, TerminalColors.defaultForeground);
      expect(ts.style!.backgroundColor, isNull);
      expect(ts.style!.fontWeight, FontWeight.normal);
      expect(ts.style!.fontStyle, FontStyle.normal);
      expect(ts.style!.decoration, TextDecoration.none);
    });

    test('toTextSpan with bold', () {
      const span = StyledSpan(text: 'bold', bold: true);
      final ts = span.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      expect(ts.style!.fontWeight, FontWeight.bold);
    });

    test('toTextSpan with italic', () {
      const span = StyledSpan(text: 'italic', italic: true);
      final ts = span.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      expect(ts.style!.fontStyle, FontStyle.italic);
    });

    test('toTextSpan with underline', () {
      const span = StyledSpan(text: 'underline', underline: true);
      final ts = span.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      expect(ts.style!.decoration, TextDecoration.underline);
    });

    test('toTextSpan with strikethrough', () {
      const span = StyledSpan(text: 'strike', strikethrough: true);
      final ts = span.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      expect(ts.style!.decoration, TextDecoration.lineThrough);
    });

    test('toTextSpan with combined underline and strikethrough', () {
      const span =
          StyledSpan(text: 'both', underline: true, strikethrough: true);
      final ts = span.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      expect(ts.style!.decoration,
          TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]));
    });

    test('toTextSpan with non-default background sets backgroundColor', () {
      const span = StyledSpan(
        text: 'bg',
        background: TerminalColors.red,
      );
      final ts = span.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      expect(ts.style!.backgroundColor, TerminalColors.red);
    });

    test('toTextSpan with default background sets backgroundColor to null', () {
      const span = StyledSpan(
        text: 'default bg',
        background: TerminalColors.defaultBackground,
      );
      final ts = span.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      expect(ts.style!.backgroundColor, isNull);
    });

    test('toTextSpan with custom foreground color', () {
      const span = StyledSpan(
        text: 'colored',
        foreground: TerminalColors.brightGreen,
      );
      final ts = span.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      expect(ts.style!.color, TerminalColors.brightGreen);
    });

    test('toString includes text and properties', () {
      const span = StyledSpan(text: 'hello', bold: true);
      final str = span.toString();
      expect(str, contains('hello'));
      expect(str, contains('bold=true'));
    });
  });

  group('StyledLine', () {
    test('plainText joins all span texts', () {
      final line = StyledLine([
        const StyledSpan(text: 'Hello '),
        const StyledSpan(text: 'World'),
      ]);
      expect(line.plainText, 'Hello World');
    });

    test('plainText with single span', () {
      final line = StyledLine([const StyledSpan(text: 'only')]);
      expect(line.plainText, 'only');
    });

    test('plainText with empty spans list returns empty string', () {
      final line = StyledLine(const []);
      expect(line.plainText, '');
    });

    test('toTextSpan with single span returns direct TextSpan', () {
      final line = StyledLine([const StyledSpan(text: 'single')]);
      final ts = line.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      // Single span: returns the span directly, no children.
      expect(ts.text, 'single');
      expect(ts.children, isNull);
    });

    test('toTextSpan with multiple spans returns TextSpan with children', () {
      final line = StyledLine([
        const StyledSpan(text: 'a'),
        const StyledSpan(text: 'b'),
        const StyledSpan(text: 'c'),
      ]);
      final ts = line.toTextSpan(fontFamily: 'Mono', fontSize: 14.0);
      expect(ts.text, isNull);
      expect(ts.children, hasLength(3));
    });

    test('StyledLine.empty creates line with no spans', () {
      final line = StyledLine.empty();
      expect(line.spans, isEmpty);
      expect(line.plainText, '');
    });

    test('toString includes plain text', () {
      final line = StyledLine([const StyledSpan(text: 'test line')]);
      expect(line.toString(), contains('test line'));
    });

    group('toSelectedTextSpan', () {
      test('inverts colors on selected range for single span', () {
        final line = StyledLine([
          const StyledSpan(
            text: 'Hello World',
            foreground: TerminalColors.defaultForeground,
            background: TerminalColors.defaultBackground,
          ),
        ]);

        final ts = line.toSelectedTextSpan(
          fontFamily: 'Mono',
          fontSize: 14.0,
          startCol: 6,
          endCol: 11,
        );

        // Should produce children: "Hello " (normal) + "World" (inverted).
        expect(ts.children, hasLength(2));
        final normal = ts.children![0] as TextSpan;
        final inverted = ts.children![1] as TextSpan;
        expect(normal.text, 'Hello ');
        expect(normal.style!.color, TerminalColors.defaultForeground);
        expect(inverted.text, 'World');
        // Inverted: foreground becomes background, background becomes foreground.
        expect(inverted.style!.color, TerminalColors.defaultBackground);
        expect(inverted.style!.backgroundColor, TerminalColors.defaultForeground);
      });

      test('fully selected single span inverts entire text', () {
        final line = StyledLine([
          const StyledSpan(text: 'Full'),
        ]);

        final ts = line.toSelectedTextSpan(
          fontFamily: 'Mono',
          fontSize: 14.0,
          startCol: 0,
          endCol: 4,
        );

        // Single child → returned directly.
        expect(ts.text, 'Full');
        expect(ts.style!.color, TerminalColors.defaultBackground);
      });

      test('handles selection across multiple spans', () {
        final line = StyledLine([
          const StyledSpan(text: 'AAA'),
          const StyledSpan(text: 'BBB'),
          const StyledSpan(text: 'CCC'),
        ]);

        // Select columns 2..7 → "A" + "BBB" + "C" selected
        final ts = line.toSelectedTextSpan(
          fontFamily: 'Mono',
          fontSize: 14.0,
          startCol: 2,
          endCol: 7,
        );

        expect(ts.children, isNotNull);
        final texts = _extractTexts(ts);
        expect(texts, ['AA', 'A', 'BBB', 'C', 'CC']);
      });

      test('no selection overlap returns original spans', () {
        final line = StyledLine([
          const StyledSpan(text: 'Hello'),
        ]);

        final ts = line.toSelectedTextSpan(
          fontFamily: 'Mono',
          fontSize: 14.0,
          startCol: 10,
          endCol: 15,
        );

        // Selection beyond text → span is entirely outside.
        expect(ts.text, 'Hello');
      });

      test('preserves bold/italic on split spans', () {
        final line = StyledLine([
          const StyledSpan(text: 'BoldText', bold: true, italic: true),
        ]);

        final ts = line.toSelectedTextSpan(
          fontFamily: 'Mono',
          fontSize: 14.0,
          startCol: 0,
          endCol: 4,
        );

        expect(ts.children, hasLength(2));
        final selected = ts.children![0] as TextSpan;
        final normal = ts.children![1] as TextSpan;
        expect(selected.text, 'Bold');
        expect(selected.style!.fontWeight, FontWeight.bold);
        expect(selected.style!.fontStyle, FontStyle.italic);
        expect(normal.text, 'Text');
        expect(normal.style!.fontWeight, FontWeight.bold);
      });
    });
  });
}

/// Recursively extracts all plain text from a TextSpan tree.
List<String> _extractTexts(TextSpan span) {
  final result = <String>[];
  if (span.text != null) result.add(span.text!);
  if (span.children != null) {
    for (final child in span.children!) {
      result.addAll(_extractTexts(child as TextSpan));
    }
  }
  return result;
}
