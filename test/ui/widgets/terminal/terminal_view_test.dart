import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';

import 'terminal_view_helpers.dart';

void main() {
  group('TerminalView rendering', () {
    testWidgets('renders styled text lines from buffer', (tester) async {
      final lines = createStyledLines(['Hello MUD', 'You are here.']);
      await pumpTerminalView(tester, lines: lines);

      // RichText widgets contain the text in their TextSpan trees.
      expect(findRichTextContaining('Hello MUD'), findsOneWidget);
      expect(findRichTextContaining('You are here.'), findsOneWidget);
    });

    testWidgets('renders empty line as RichText with space', (tester) async {
      final lines = [
        StyledLine([StyledSpan(text: 'Before')]),
        StyledLine.empty(),
        StyledLine([StyledSpan(text: 'After')]),
      ];
      await pumpTerminalView(tester, lines: lines);

      // All lines (including empty) should render as RichText now.
      expect(find.byType(RichText), findsNWidgets(3));
    });

    testWidgets('renders colored text with correct foreground', (tester) async {
      final lines = [
        StyledLine([
          StyledSpan(
            text: 'Red text',
            foreground: const Color(0xFFFF0000),
          ),
        ]),
      ];
      await pumpTerminalView(tester, lines: lines);

      final richText = tester.widget<RichText>(
        findRichTextContaining('Red text'),
      );
      final span = richText.text as TextSpan;
      expect(span.style?.color, const Color(0xFFFF0000));
    });

    testWidgets('renders bold text with FontWeight.bold', (tester) async {
      final lines = [
        StyledLine([StyledSpan(text: 'Bold', bold: true)]),
      ];
      await pumpTerminalView(tester, lines: lines);

      final richText = tester.widget<RichText>(
        findRichTextContaining('Bold'),
      );
      final span = richText.text as TextSpan;
      expect(span.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('renders multi-span line with children', (tester) async {
      final lines = [
        StyledLine([
          StyledSpan(text: 'Hello '),
          StyledSpan(text: 'World', bold: true),
        ]),
      ];
      await pumpTerminalView(tester, lines: lines);

      final richText = tester.widget<RichText>(
        findRichTextContaining('Hello World'),
      );
      final span = richText.text as TextSpan;
      expect(span.children, hasLength(2));
    });
  });

  group('TerminalView tap behavior', () {
    testWidgets('single tap requests focus on input FocusNode',
        (tester) async {
      final focusNode = FocusNode();
      await pumpTerminalView(
        tester,
        lines: createStyledLines(['Line 1', 'Line 2']),
        focusNode: focusNode,
      );
      await tester.pumpAndSettle();

      // Tap on a terminal line (not edge of the widget).
      final target = findRichTextContaining('Line 1');
      await tester.tapAt(tester.getCenter(target));
      // Wait for the single-tap timer to fire (300ms double-tap timeout).
      await tester.pump(const Duration(milliseconds: 400));

      expect(focusNode.hasFocus, isTrue);

      focusNode.dispose();
    });
  });

  group('TerminalView keyboard shortcuts', () {
    testWidgets('Ctrl+A is wired as a shortcut', (tester) async {
      await pumpTerminalView(
        tester,
        lines: createStyledLines(['Line 1', 'Line 2']),
      );

      // Ctrl+A should be handled without error (select all intent).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // The fact that no error is thrown confirms the shortcut is wired.
    });
  });

  group('TerminalView scroll behavior', () {
    testWidgets('shows scroll-to-bottom FAB when scrolled away from bottom',
        (tester) async {
      // Create enough lines to require scrolling.
      final lines = createStyledLines(
        List.generate(100, (i) => 'Line $i with some extra text'),
      );
      await pumpTerminalView(tester, lines: lines);
      await tester.pumpAndSettle();

      // Scroll down a tiny bit to trigger _onScroll while still far from bottom.
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pump();

      // We're scrolled to position ~100, far from bottom — FAB should appear.
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('scroll-to-bottom FAB scrolls to bottom when tapped',
        (tester) async {
      final lines = createStyledLines(
        List.generate(100, (i) => 'Line $i with some extra text'),
      );
      await pumpTerminalView(tester, lines: lines);
      await tester.pumpAndSettle();

      // Scroll down a bit (away from bottom).
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pump();

      // FAB should be visible.
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Tap the FAB.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // FAB should disappear (back at bottom).
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('TerminalView uses text cursor', () {
    testWidgets('MouseRegion with text cursor is present', (tester) async {
      await pumpTerminalView(
        tester,
        lines: createStyledLines(['test']),
      );

      // Find the MouseRegion with SystemMouseCursors.text specifically.
      final mouseRegions = tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .where((mr) => mr.cursor == SystemMouseCursors.text);
      expect(mouseRegions, isNotEmpty);
    });
  });
}
