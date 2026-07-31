import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';

import 'terminal_view_helpers.dart';

/// Long-pressing a reddish kill link is the escape hatch for a false positive
/// the static blocklists haven't learned yet.
void main() {
  StyledLine lineWithLink(String before, String word, String command) =>
      StyledLine([
        StyledSpan(text: before),
        StyledSpan(text: word, command: command),
        const StyledSpan(text: ' hits you.'),
      ]);

  testWidgets('long-pressing a kill link offers to stop highlighting it',
      (tester) async {
    final container = await pumpTerminalView(
      tester,
      lines: [lineWithLink('The ', 'goblin', 'kill goblin')],
    );

    await tester.longPress(find.text('goblin'));
    await tester.pumpAndSettle();

    expect(find.text('Stop highlighting this'), findsOneWidget);
    expect(find.text('Ignored targets…'), findsOneWidget);

    await tester.tap(find.text('Stop highlighting this'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).ignoredKillTargets, ['goblin']);
  });

  testWidgets('the confirmation can be undone', (tester) async {
    final container = await pumpTerminalView(
      tester,
      lines: [lineWithLink('The ', 'orc', 'kill orc')],
    );

    await tester.longPress(find.text('orc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop highlighting this'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).ignoredKillTargets, ['orc']);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).ignoredKillTargets, isEmpty);
  });

  testWidgets('a user text-link rule is left alone', (tester) async {
    // The ignore list exists for the kill-link heuristic; a rule the user wrote
    // themselves has no false positives to escape.
    await pumpTerminalView(
      tester,
      lines: [lineWithLink('The dark ', 'door', 'open dark door')],
    );

    await tester.longPress(find.text('door'));
    await tester.pumpAndSettle();

    expect(find.text('Stop highlighting this'), findsNothing);
  });

  testWidgets('tapping a kill link still sends it', (tester) async {
    // The long-press must not have stolen the tap.
    final container = await pumpTerminalView(
      tester,
      lines: [lineWithLink('The ', 'goblin', 'kill goblin')],
    );

    await tester.tap(find.text('goblin'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).ignoredKillTargets, isEmpty);
    expect(find.text('Stop highlighting this'), findsNothing);
  });
}
