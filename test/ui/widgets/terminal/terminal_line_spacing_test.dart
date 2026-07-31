import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/line_spacing.dart';
import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/terminal_line.dart';

void main() {
  Future<double> lineHeight(
    WidgetTester tester, {
    required double extraSpacing,
    bool blank = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalLine(
            line: blank
                ? StyledLine.empty()
                : StyledLine([const StyledSpan(text: 'You are here.')]),
            lineIndex: 0,
            fontSize: 14,
            extraSpacing: extraSpacing,
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(TerminalLine)).height;
  }

  group('TerminalLine extraSpacing', () {
    testWidgets('adds the full amount, split above and below', (tester) async {
      final base = await lineHeight(tester, extraSpacing: 0);
      final spaced = await lineHeight(tester, extraSpacing: 7);
      expect(spaced - base, closeTo(7, 0.01));
    });

    testWidgets('applies to blank lines too', (tester) async {
      // Blank lines take an early-return path in build(); if they kept the
      // baseline padding the terminal's uniform line-height maths — and with
      // it selection and link hit-testing — would drift on every blank line.
      final base = await lineHeight(tester, extraSpacing: 0, blank: true);
      final spaced = await lineHeight(tester, extraSpacing: 7, blank: true);
      expect(spaced - base, closeTo(7, 0.01));
    });

    testWidgets('defaults to no extra spacing', (tester) async {
      final explicit = await lineHeight(tester, extraSpacing: 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalLine(
              line: StyledLine([const StyledSpan(text: 'You are here.')]),
              lineIndex: 0,
              fontSize: 14,
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TerminalLine)).height, explicit);
    });

    testWidgets('matches what the settings enum asks for', (tester) async {
      final base = await lineHeight(tester, extraSpacing: 0);
      for (final spacing in LineSpacing.values) {
        final height =
            await lineHeight(tester, extraSpacing: spacing.extraFor(14));
        expect(height - base, closeTo(14 * spacing.percent / 100, 0.01));
      }
    });
  });
}
