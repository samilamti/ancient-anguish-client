import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/local_features_provider.dart';
import 'package:ancient_anguish_client/ui/screens/history_screen.dart';

/// Creating rules from a selection in the History scrollback: the selection
/// menu gains the same "Create Text Link Rule" / "Create Trigger" actions as
/// the live terminal, opening the existing editor seeded from the selection.
void main() {
  Future<void> pumpHistory(WidgetTester tester, {bool local = false}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          terminalBufferProvider.overrideWith(_FakeBuffer.new),
          localFeaturesAvailableProvider.overrideWith((ref) async => local),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectWord(WidgetTester tester) async {
    // Press near the start: the line's box spans the full width, so its
    // centre can sit past the end of the text.
    final line = find.text('Portcullis', findRichText: true);
    await tester.longPressAt(tester.getTopLeft(line) + const Offset(12, 6));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String label) => tester
      .widget<TextField>(find.widgetWithText(TextField, label))
      .controller!
      .text;

  testWidgets('Create Text Link Rule seeds the pattern from the selection',
      (tester) async {
    await pumpHistory(tester);
    await selectWord(tester);

    expect(find.text('Create Trigger'), findsNothing,
        reason: 'triggers are local-only');
    await tester.tap(find.text('Create Text Link Rule'));
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'Pattern (regex)'), 'Portcullis');
    expect(fieldText(tester, 'Test input'), 'Portcullis');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Create Trigger appears in local builds and seeds the pattern',
      (tester) async {
    await pumpHistory(tester, local: true);
    await selectWord(tester);

    // The Android toolbar overflows its last items into a "more" menu.
    if (find.text('Create Trigger').evaluate().isEmpty) {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Create Trigger'));
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'Pattern (regex)'), 'Portcullis');
    debugDefaultTargetPlatformOverride = null;
  });
}

class _FakeBuffer extends TerminalBufferNotifier {
  @override
  List<StyledLine> build() => [
        StyledLine([const StyledSpan(text: 'Portcullis')]),
      ];
}
