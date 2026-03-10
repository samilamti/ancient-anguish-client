import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/core/theme/app_theme.dart';
import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/terminal_view.dart';

/// Creates [StyledLine] objects from plain text strings (no ANSI styling).
List<StyledLine> createStyledLines(List<String> texts) {
  return texts.map((t) => StyledLine([StyledSpan(text: t)])).toList();
}

/// A fake [TerminalBufferNotifier] that skips all connection/parser setup.
///
/// Overrides [build] to return initial lines directly, avoiding the need to
/// mock ConnectionService, OutputParser, TriggerEngine, etc.
class FakeTerminalBufferNotifier extends TerminalBufferNotifier {
  final List<StyledLine> _initialLines;
  FakeTerminalBufferNotifier(this._initialLines);

  @override
  List<StyledLine> build() => List.of(_initialLines);
}

/// Pumps a minimal widget tree containing [TerminalView] with provider
/// overrides for testing.
///
/// Returns the [ProviderContainer] for direct state manipulation.
Future<ProviderContainer> pumpTerminalView(
  WidgetTester tester, {
  List<StyledLine> lines = const [],
  FocusNode? focusNode,
}) async {
  final inputFocus = focusNode ?? FocusNode();

  final container = ProviderContainer(
    overrides: [
      terminalBufferProvider
          .overrideWith(() => FakeTerminalBufferNotifier(lines)),
      inputFocusProvider.overrideWithValue(inputFocus),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.rpgDark(),
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: TerminalView()),
              // Attach the input FocusNode to a real widget so requestFocus
              // works in tests.
              Focus(focusNode: inputFocus, child: const SizedBox(height: 1)),
            ],
          ),
        ),
      ),
    ),
  );

  return container;
}

/// Sets up a mock clipboard handler on the platform channel.
///
/// Returns a getter function that retrieves the last clipboard content.
String? Function() setupClipboardMock(WidgetTester tester) {
  String? content;

  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        content = (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': content};
      }
      return null;
    },
  );

  return () => content;
}

/// Finds [RichText] widgets that contain the given text string in their spans.
Finder findRichTextContaining(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is! RichText) return false;
    return widget.text.toPlainText().contains(text);
  });
}
