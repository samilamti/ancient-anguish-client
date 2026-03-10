import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
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
      });
    });

    group('onSelectionChanged', () {
      test('with non-empty content sets hasSelection to true', () {
        final content = SelectedContent(plainText: 'hello');
        controller.onSelectionChanged(content);
        expect(controller.hasSelection, isTrue);
      });

      test('with null sets hasSelection to false', () {
        // First set a selection.
        controller.onSelectionChanged(SelectedContent(plainText: 'hi'));
        expect(controller.hasSelection, isTrue);

        // Then clear it.
        controller.onSelectionChanged(null);
        expect(controller.hasSelection, isFalse);
      });

      test('with empty text sets hasSelection to false', () {
        controller.onSelectionChanged(SelectedContent(plainText: ''));
        expect(controller.hasSelection, isFalse);
      });

      test('returns true when state changes', () {
        final changed =
            controller.onSelectionChanged(SelectedContent(plainText: 'x'));
        expect(changed, isTrue);
      });

      test('returns false when state is unchanged', () {
        controller.onSelectionChanged(SelectedContent(plainText: 'x'));
        final changed =
            controller.onSelectionChanged(SelectedContent(plainText: 'y'));
        expect(changed, isFalse); // still has selection
      });

      test('returns true when clearing selection', () {
        controller.onSelectionChanged(SelectedContent(plainText: 'x'));
        final changed = controller.onSelectionChanged(null);
        expect(changed, isTrue);
      });
    });

    group('copySelectionToClipboard', () {
      testWidgets('copies plainText to clipboard', (tester) async {
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

        controller
            .onSelectionChanged(SelectedContent(plainText: 'copied text'));
        await controller.copySelectionToClipboard();

        expect(clipboardContent, 'copied text');
      });

      testWidgets('with no selection is a no-op', (tester) async {
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

        await controller.copySelectionToClipboard();
        expect(clipboardCalled, isFalse);
      });

      testWidgets('with empty text selection is a no-op', (tester) async {
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

        controller.onSelectionChanged(SelectedContent(plainText: ''));
        await controller.copySelectionToClipboard();
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
