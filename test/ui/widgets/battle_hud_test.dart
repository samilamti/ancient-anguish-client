import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/battle_stats_provider.dart';
import 'package:ancient_anguish_client/services/parser/battle_text_classifier.dart';
import 'package:ancient_anguish_client/ui/widgets/status/battle_hud.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  /// Pumps the dock the way HomeScreen does: a sibling below the terminal in
  /// the main column, not an overlay on top of it.
  Future<void> pumpDock(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SizedBox.expand(key: Key('fake-terminal')),
                ),
                BattleHudDock(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The dock's own fade. Scoped, because MaterialApp's route machinery has
  /// FadeTransitions of its own and an unscoped finder matches several.
  double dockOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(find.descendant(
        of: find.byType(BattleHudDock),
        matching: find.byType(FadeTransition),
      ))
      .opacity
      .value;

  Future<void> pumpHud(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(bottom: 8, right: 12, child: BattleHud()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void feed(Iterable<String> lines) {
    final notifier = container.read(battleStatsProvider.notifier);
    for (final line in lines) {
      final match = BattleTextClassifier.classify(line);
      expect(match, isNotNull, reason: 'Fixture must classify: "$line"');
      notifier.record(match!, rawLine: line);
    }
  }

  /// Lets the stats notifier's idle timer fire. The test framework asserts on
  /// timers still pending when the tree is torn down, and that assertion runs
  /// before `tearDown` disposes the container.
  Future<void> drainIdleTimer(WidgetTester tester) => tester.pump(
        BattleStatsNotifier.battleTimeout + const Duration(seconds: 1),
      );

  testWidgets('renders nothing before a fight has started', (tester) async {
    await pumpHud(tester);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('shows the target, tallies and latest line', (tester) async {
    feed([
      "You pounded Nurse's leg heartlessly.",
      "You pounded Nurse's head heartlessly.",
      'You missed.',
      'Nurse pounded your head heartlessly.',
      'Nurse missed you.',
      'HP:  88  SP:  79',
      'HP:  82  SP:  75',
      'Nurse battered your leg.',
    ]);
    await pumpHud(tester);

    // Target and the verbatim latest line — the two things that make the HUD a
    // replacement for the gagged text rather than just a scoreboard.
    expect(find.text('Nurse'), findsOneWidget);
    expect(find.text('Nurse battered your leg.'), findsOneWidget);

    // Scoreboard rows.
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Taken'), findsOneWidget);
    expect(find.text('67% acc'), findsOneWidget); // 2 hits of 3 swings
    expect(find.text('33% evd'), findsOneWidget); // 1 miss of 3 incoming

    // Vitals carried over from the gagged `HP:/SP:` lines, plus HP lost since
    // the fight's first reading.
    expect(find.text('82'), findsOneWidget);
    expect(find.text('75'), findsOneWidget);
    expect(find.text('-6'), findsOneWidget);

    // Round counter from the two vitals lines.
    expect(find.textContaining('r2'), findsOneWidget);

    await drainIdleTimer(tester);
  });

  testWidgets('hides the Others row until a third party acts', (tester) async {
    feed(["You pounded Nurse's leg heartlessly."]);
    await pumpHud(tester);
    expect(find.text('Others'), findsNothing);

    feed(["Mummy pierced Nurse's head keenly."]);
    await tester.pump();
    expect(find.text('Others'), findsOneWidget);

    await drainIdleTimer(tester);
  });

  testWidgets('shows a kill tally once something dies', (tester) async {
    feed(["You pounded Nurse's leg heartlessly."]);
    await pumpHud(tester);
    expect(find.textContaining('☠'), findsNothing);

    feed(['You killed Nurse.']);
    await tester.pump();
    expect(find.text('☠ 1'), findsOneWidget);

    await drainIdleTimer(tester);
  });

  testWidgets('stays readable after combat goes quiet', (tester) async {
    feed([
      "You pounded Nurse's leg heartlessly.",
      'You killed Nurse.',
    ]);
    await pumpHud(tester);

    // Past the idle timeout: the fight is over but the outcome must still be
    // on screen when the player looks up.
    await tester.pump(BattleStatsNotifier.battleTimeout + const Duration(seconds: 1));

    expect(container.read(battleStatsProvider).active, isFalse);
    expect(find.text('Nurse'), findsOneWidget);
    expect(find.text('You killed Nurse.'), findsOneWidget);
  });

  testWidgets('lays out without overflow on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    feed([
      "Mummy pierced Nurse's head keenly.",
      "You pounded Nurse's leg heartlessly.",
      'Nurse pounded your head heartlessly.',
      'Mummy missed Nurse.',
      'HP:  88  SP:  79',
      // A long line is the realistic overflow risk — it must ellipsize.
      "You duck your head quickly as Nurse's blow flies over you.",
    ]);
    await pumpHud(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(BattleHud), findsOneWidget);

    await drainIdleTimer(tester);
  });

  group('BattleHudDock', () {
    testWidgets('takes no space at all outside combat', (tester) async {
      await pumpDock(tester);
      expect(tester.getSize(find.byType(BattleHudDock)).height, 0);
    });

    testWidgets('reserves space below the terminal during a fight',
        (tester) async {
      await pumpDock(tester);
      final terminalBefore = tester.getSize(find.byKey(const Key('fake-terminal'))).height;

      feed(["You pounded Nurse's leg heartlessly."]);
      await tester.pumpAndSettle();

      final dock = tester.getRect(find.byType(BattleHudDock));
      expect(dock.height, greaterThan(0));
      // The panel can only be covering the newest output if the terminal
      // didn't actually give up the room.
      expect(
        tester.getSize(find.byKey(const Key('fake-terminal'))).height,
        lessThanOrEqualTo(terminalBefore - dock.height),
      );
      // ...and it sits below it, not over it.
      expect(dock.top,
          greaterThanOrEqualTo(tester.getRect(find.byKey(const Key('fake-terminal'))).bottom));

      await drainIdleTimer(tester);
    });

    testWidgets('is left aligned', (tester) async {
      feed(["You pounded Nurse's leg heartlessly."]);
      await pumpDock(tester);
      await tester.pumpAndSettle();

      final screen = tester.getRect(find.byType(Scaffold));
      final panel = tester.getRect(find.byType(BattleHud));
      expect(panel.left - screen.left, lessThan(24));
      expect(screen.right - panel.right, greaterThan(panel.left - screen.left));

      await drainIdleTimer(tester);
    });
    testWidgets('fades and grows in as the fight starts', (tester) async {
      await pumpDock(tester);
      feed(["You pounded Nurse's leg heartlessly."]);

      // Mid-fade: partially transparent and only partially tall.
      await tester.pump();
      await tester.pump(BattleHudDock.fadeDuration ~/ 2);
      final midOpacity = dockOpacity(tester);
      final midHeight = tester.getSize(find.byType(BattleHudDock)).height;
      expect(midOpacity, greaterThan(0));
      expect(midOpacity, lessThan(1));
      expect(midHeight, greaterThan(0));

      await tester.pumpAndSettle();
      expect(dockOpacity(tester), 1);
      expect(tester.getSize(find.byType(BattleHudDock)).height,
          greaterThan(midHeight));

      await drainIdleTimer(tester);
      await tester.pumpAndSettle();
    });

    testWidgets('fades out and gives the space back when the fight ends',
        (tester) async {
      await pumpDock(tester);
      feed(["You pounded Nurse's leg heartlessly."]);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(BattleHudDock)).height, greaterThan(0));

      // Past the idle timeout the fight is over, so the panel leaves. The
      // outcome stays readable in the terminal — resolution lines are never
      // filtered — which is what makes removing it safe.
      await drainIdleTimer(tester);
      await tester.pumpAndSettle();

      expect(dockOpacity(tester), 0);
      expect(tester.getSize(find.byType(BattleHudDock)).height, 0);
    });

    testWidgets('mounting mid-fight shows the panel without animating in',
        (tester) async {
      // Switching the mode on during combat shouldn't play a fade-in.
      feed(["You pounded Nurse's leg heartlessly."]);
      await pumpDock(tester);

      expect(dockOpacity(tester), 1);

      await drainIdleTimer(tester);
      await tester.pumpAndSettle();
    });
  });
}