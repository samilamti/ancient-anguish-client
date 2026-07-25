import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/core/theme/app_theme.dart';
import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/terminal_view.dart';

import 'terminal_view_helpers.dart';

void main() {
  /// True when any rendered span carries a background colour — the terminal's
  /// inverse-video selection highlight (see `StyledLine.toSelectedTextSpan`).
  bool hasSelectionHighlight(WidgetTester tester) {
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      var found = false;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.style?.backgroundColor != null) {
          found = true;
        }
        return !found;
      });
      if (found) return true;
    }
    return false;
  }

  group('TerminalView tap clears an active selection', () {
    testWidgets('a tap on the output drops the selection without stealing '
        'input focus', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await pumpTerminalView(
        tester,
        lines: createStyledLines(
          List.generate(40, (i) => 'You must be standing.'),
        ),
        focusNode: focusNode,
      );
      await tester.pumpAndSettle();

      // Drag across a line to make a real selection; pointer-up pops the
      // context menu, which we dismiss by tapping its barrier.
      final listRect = tester.getRect(find.byType(ListView));
      await tester.dragFrom(
        Offset(listRect.left + 12, listRect.center.dy),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      // The highlight survives the menu dismissal.
      expect(hasSelectionHighlight(tester), isTrue);

      // Tapping the output again clears it — and, because this tap was
      // dismissing a selection, it does not pull focus to the input bar.
      await tester.tapAt(listRect.center);
      await tester.pump(const Duration(milliseconds: 400));

      expect(hasSelectionHighlight(tester), isFalse);
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('a tap with no selection still focuses the input',
        (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await pumpTerminalView(
        tester,
        lines: createStyledLines(['Line 1', 'Line 2']),
        focusNode: focusNode,
      );
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(findRichTextContaining('Line 1')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(focusNode.hasFocus, isTrue);
    });
  });

  group('TerminalView text-link taps', () {
    /// Pumps a TerminalView at [size] holding one command-link span.
    Future<_FakeConnectionService> pumpWithLink(
      WidgetTester tester, {
      required Size size,
      required FocusNode focusNode,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final service = _FakeConnectionService();
      final lines = [
        StyledLine([
          const StyledSpan(text: 'A large '),
          const StyledSpan(text: 'goblin', command: 'kill goblin'),
          const StyledSpan(text: ' blocks the path.'),
        ]),
      ];

      final container = ProviderContainer(
        overrides: [
          terminalBufferProvider
              .overrideWith(() => FakeTerminalBufferNotifier(lines)),
          inputFocusProvider.overrideWithValue(focusNode),
          connectionServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.rpgDark(),
            home: Scaffold(
              body: Column(
                children: [
                  const Expanded(child: TerminalView()),
                  Focus(focusNode: focusNode, child: const SizedBox(height: 1)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets('tapping a link on mobile sends the command and dismisses '
        'the keyboard', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final service = await pumpWithLink(
        tester,
        size: const Size(400, 800),
        focusNode: focusNode,
      );
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);

      await tester.tap(find.text('goblin'));
      await tester.pumpAndSettle();

      expect(service.sentCommands, ['kill goblin']);
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('tapping a link on desktop keeps input focus', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final service = await pumpWithLink(
        tester,
        size: const Size(1200, 900),
        focusNode: focusNode,
      );
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      await tester.tap(find.text('goblin'));
      await tester.pumpAndSettle();

      expect(service.sentCommands, ['kill goblin']);
      expect(focusNode.hasFocus, isTrue);
    });
  });
}

class _FakeConnectionService extends TcpConnectionService {
  final List<String> sentCommands = [];

  @override
  bool get isConnected => true;

  @override
  void sendCommand(String command) {
    sentCommands.add(command);
  }
}
