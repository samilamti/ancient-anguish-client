import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/terminal_line.dart';

/// Selecting scrollback text in the History screen.
///
/// The History screen has always wrapped its list in a `SelectionArea`, but
/// nothing was selectable: a hand-built `RichText` does not join a selection
/// area on its own — only `Text`/`Text.rich` pass a registrar down. So the
/// area existed and had no participants.
void main() {
  List<StyledLine> lines() => [
        StyledLine([const StyledSpan(text: 'You see a forest.')]),
        StyledLine.empty(),
        StyledLine([const StyledSpan(text: 'The path leads east.')]),
      ];

  Widget wrap({required bool inSelectionArea}) {
    final list = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines().length; i++)
          TerminalLine(line: lines()[i], lineIndex: i, fontSize: 14),
      ],
    );
    return MaterialApp(
      home: Scaffold(
        body: inSelectionArea ? SelectionArea(child: list) : list,
      ),
    );
  }

  Iterable<RichText> richTexts(WidgetTester tester) =>
      tester.widgetList<RichText>(find.descendant(
        of: find.byType(TerminalLine),
        matching: find.byType(RichText),
      ));

  testWidgets('every line joins an enclosing SelectionArea', (tester) async {
    await tester.pumpWidget(wrap(inSelectionArea: true));

    final texts = richTexts(tester).toList();
    expect(texts, hasLength(3), reason: 'blank lines participate too');
    for (final text in texts) {
      expect(text.selectionRegistrar, isNotNull);
      // RichText asserts a colour is supplied alongside a registrar.
      expect(text.selectionColor, isNotNull);
    }
  });

  testWidgets('outside a SelectionArea nothing registers', (tester) async {
    // The live terminal runs its own pointer-level selection and has no
    // SelectionContainer above it; it must keep getting a null registrar.
    await tester.pumpWidget(wrap(inSelectionArea: false));

    for (final text in richTexts(tester)) {
      expect(text.selectionRegistrar, isNull);
      expect(text.selectionColor, isNull);
    }
  });

  testWidgets('dragging across lines selects text that can be copied',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(wrap(inSelectionArea: true));

    final first = tester.getRect(find.byType(TerminalLine).first);
    final last = tester.getRect(find.byType(TerminalLine).last);
    // A mouse drag: SelectionArea deliberately does not start a selection from
    // a touch drag (that gesture belongs to scrolling).
    final gesture = await tester.startGesture(
      first.centerLeft + const Offset(2, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(last.centerRight - const Offset(2, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(copied, isNotNull,
        reason: 'a drag inside the SelectionArea should be copyable');
    expect(copied, contains('forest'));
    expect(copied, contains('east'));
  });
}
