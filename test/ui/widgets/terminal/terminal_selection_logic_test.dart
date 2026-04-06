import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/terminal_selection.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/terminal_selection_controller.dart';

void main() {
  late TerminalSelectionController controller;

  setUp(() {
    controller = TerminalSelectionController();
  });

  group('TerminalSelectionController', () {
    group('initial state', () {
      test('has no selection', () {
        expect(controller.hasSelection, isFalse);
        expect(controller.selection, isNull);
      });
    });

    group('startSelection', () {
      test('creates a zero-width selection at the given position', () {
        final changed = controller.startSelection(
          const TerminalPosition(2, 5),
        );
        expect(changed, isTrue);
        expect(controller.hasSelection, isTrue);
        expect(controller.selection!.anchor, const TerminalPosition(2, 5));
        expect(controller.selection!.focus, const TerminalPosition(2, 5));
      });

      test('returns false if already at same position', () {
        controller.startSelection(const TerminalPosition(1, 1));
        final changed = controller.startSelection(
          const TerminalPosition(1, 1),
        );
        expect(changed, isFalse);
      });
    });

    group('updateSelection', () {
      test('extends selection to new focus', () {
        controller.startSelection(const TerminalPosition(0, 0));
        final changed = controller.updateSelection(
          const TerminalPosition(3, 10),
        );
        expect(changed, isTrue);
        expect(controller.selection!.anchor, const TerminalPosition(0, 0));
        expect(controller.selection!.focus, const TerminalPosition(3, 10));
      });

      test('starts new selection if none exists', () {
        final changed = controller.updateSelection(
          const TerminalPosition(5, 2),
        );
        expect(changed, isTrue);
        expect(controller.hasSelection, isTrue);
      });

      test('returns false if focus unchanged', () {
        controller.startSelection(const TerminalPosition(0, 0));
        controller.updateSelection(const TerminalPosition(1, 5));
        final changed = controller.updateSelection(
          const TerminalPosition(1, 5),
        );
        expect(changed, isFalse);
      });
    });

    group('clearSelection', () {
      test('clears existing selection', () {
        controller.startSelection(const TerminalPosition(0, 0));
        final changed = controller.clearSelection();
        expect(changed, isTrue);
        expect(controller.hasSelection, isFalse);
        expect(controller.selection, isNull);
      });

      test('returns false if no selection to clear', () {
        expect(controller.clearSelection(), isFalse);
      });
    });

    group('selectAll', () {
      test('selects entire buffer', () {
        final changed = controller.selectAll(10, 15);
        expect(changed, isTrue);
        expect(controller.selection!.start, const TerminalPosition(0, 0));
        expect(controller.selection!.end, const TerminalPosition(9, 15));
      });

      test('returns false for empty buffer', () {
        expect(controller.selectAll(0, 0), isFalse);
      });

      test('returns false if already selecting all', () {
        controller.selectAll(5, 10);
        expect(controller.selectAll(5, 10), isFalse);
      });
    });

    group('selectLine', () {
      test('selects entire line', () {
        final changed = controller.selectLine(3, 20);
        expect(changed, isTrue);
        expect(controller.selection!.start, const TerminalPosition(3, 0));
        expect(controller.selection!.end, const TerminalPosition(3, 20));
      });
    });

    group('copyToClipboard', () {
      testWidgets('copies selected text to clipboard', (tester) async {
        String? clipboardContent;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardContent =
                  (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
            }
            return null;
          },
        );

        final lines = [
          StyledLine([StyledSpan(text: 'Hello World')]),
          StyledLine([StyledSpan(text: 'Foo Bar')]),
        ];

        controller.startSelection(const TerminalPosition(0, 6));
        controller.updateSelection(const TerminalPosition(1, 3));
        await controller.copyToClipboard(lines);

        expect(clipboardContent, 'World\nFoo');
      });

      testWidgets('is no-op with no selection', (tester) async {
        bool clipboardCalled = false;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardCalled = true;
            }
            return null;
          },
        );

        await controller.copyToClipboard([
          StyledLine([StyledSpan(text: 'test')]),
        ]);
        expect(clipboardCalled, isFalse);
      });
    });

    group('getAllText', () {
      test('joins buffer lines with newlines', () {
        final lines = [
          StyledLine([StyledSpan(text: 'Hello')]),
          StyledLine([StyledSpan(text: 'World')]),
          StyledLine([StyledSpan(text: 'Foo')]),
        ];
        expect(controller.getAllText(lines), 'Hello\nWorld\nFoo');
      });

      test('with empty buffer returns empty string', () {
        expect(controller.getAllText([]), '');
      });

      test('with single line returns that line without trailing newline', () {
        final lines = [
          StyledLine([StyledSpan(text: 'Only line')]),
        ];
        expect(controller.getAllText(lines), 'Only line');
      });

      test('handles lines with multiple styled spans', () {
        final lines = [
          StyledLine([
            StyledSpan(text: 'Red '),
            StyledSpan(text: 'Blue'),
          ]),
          StyledLine([StyledSpan(text: 'Plain')]),
        ];
        expect(controller.getAllText(lines), 'Red Blue\nPlain');
      });
    });
  });
}
