import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/battle_stats.dart';
import 'package:ancient_anguish_client/providers/battle_stats_provider.dart';
import 'package:ancient_anguish_client/services/parser/battle_text_classifier.dart';
import 'package:ancient_anguish_client/ui/widgets/status/battle_hud.dart';

void main() {
  late ProviderContainer container;

  /// The fake wall clock the HUD reads. Advanced by hand, since pumping only
  /// moves Flutter's clock.
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 8, 1, 12);
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => now),
    ]);
  });
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

  /// Pumps long enough for the dock's fade to finish.
  ///
  /// `pumpAndSettle` cannot be used while a fight is active: the HUD pulses its
  /// border on a repeating animation, so frames are always scheduled and
  /// settling never happens. A fixed pump is the correct tool for an animation
  /// that is *meant* to run forever.
  /// Two pumps, not one: the first delivers the provider change and *starts*
  /// the animation, the second advances the clock past its duration. A single
  /// `pump(duration)` leaves the controller at 0 — the frame that begins the
  /// animation is the same one being advanced.
  Future<void> pumpFade(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(
      BattleHudDock.fadeDuration + const Duration(milliseconds: 50),
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

  /// Feeds combat lines one batch of MUD output at a time, which is how the
  /// client counts rounds — so feeding N lines advances the fight N rounds.
  void feed(Iterable<String> lines) {
    final notifier = container.read(battleStatsProvider.notifier);
    for (final line in lines) {
      final match = BattleTextClassifier.classify(line);
      expect(match, isNotNull, reason: 'Fixture must classify: "$line"');
      notifier.record(match!, rawLine: line, startsRound: true);
    }
  }

  /// The shortest fight the HUD will show itself for. Below
  /// [BattleStats.confirmRounds] rounds the panel deliberately stays hidden, so
  /// every test about what a *visible* HUD looks like has to clear that bar
  /// first.
  void feedConfirmedFight() => feed(List.filled(
        BattleStats.confirmRounds,
        "You pounded Nurse's leg heartlessly.",
      ));

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

  testWidgets('stays hidden until the fight is confirmed', (tester) async {
    // Walking through the world draws the odd swing from a stray NPC. A scuffle
    // that is over in a round or two must not flash the panel up — and, since
    // gagging is gated on the same flag, its text stays in the terminal.
    feed(List.filled(
      BattleStats.confirmRounds - 1,
      "Nurse pounded your head heartlessly.",
    ));
    await pumpHud(tester);
    expect(find.byType(Text), findsNothing);
    expect(container.read(battleStatsProvider).active, isTrue,
        reason: 'The fight is running — it just has not earned the panel yet.');

    // The round that reaches the threshold brings it on screen.
    feed(['Nurse missed you.']);
    await tester.pump();
    expect(find.text('Nurse'), findsOneWidget);

    await drainIdleTimer(tester);
  });

  testWidgets('the dock keeps its space until the fight is confirmed',
      (tester) async {
    await pumpDock(tester);
    feed(List.filled(
      BattleStats.confirmRounds - 1,
      "Nurse pounded your head heartlessly.",
    ));
    await pumpFade(tester);
    expect(tester.getSize(find.byType(BattleHudDock)).height, 0);

    feed(['Nurse missed you.']);
    await pumpFade(tester);
    expect(tester.getSize(find.byType(BattleHudDock)).height, greaterThan(0));

    await drainIdleTimer(tester);
    await pumpFade(tester);
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
    // "Target", not "Taken" — the row is what the target managed against you.
    expect(find.text('Target'), findsOneWidget);
    // Labels spelled out: the HUD replaces the combat text, so it should not
    // need decoding.
    expect(find.text('67% accuracy'), findsOneWidget); // 2 hits of 3 swings
    expect(find.text('33% evade'), findsOneWidget); // 1 miss of 3 incoming

    // Vitals carried over from the gagged `HP:/SP:` lines, plus HP lost since
    // the fight's first reading.
    expect(find.text('82'), findsOneWidget);
    expect(find.text('75'), findsOneWidget);
    expect(find.text('-6'), findsOneWidget);

    // One round per batch of combat output — eight batches above — spelled out
    // rather than abbreviated. Not the two `HP:/SP:` lines: those set the
    // vitals, but AA doesn't reliably print one per round, which is what used
    // to leave this stuck on nothing for a whole fight.
    expect(find.textContaining('round 8'), findsOneWidget);

    await drainIdleTimer(tester);
  });

  testWidgets('never shows a third-party row', (tester) async {
    // The Others row was dropped: the classifier can tell neither participant
    // is the player but not which side they are on, so the number meant too
    // little to earn a line in a panel this small. The tallies are still
    // recorded — see battle_stats_provider_test.
    feedConfirmedFight();
    await pumpHud(tester);
    expect(find.text('Others'), findsNothing);

    feed(["Mummy pierced Nurse's head keenly."]);
    await tester.pump();
    expect(find.text('Others'), findsNothing);

    await drainIdleTimer(tester);
  });

  testWidgets('shows a kill tally once something dies', (tester) async {
    feedConfirmedFight();
    await pumpHud(tester);
    expect(find.textContaining('☠'), findsNothing);

    feed(['You killed Nurse.']);
    await tester.pump();
    expect(find.text('☠ 1'), findsOneWidget);

    await drainIdleTimer(tester);
  });

  testWidgets('stays readable after combat goes quiet', (tester) async {
    feedConfirmedFight();
    feed(['You killed Nurse.']);
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

      feedConfirmedFight();
      await pumpFade(tester);

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
      feedConfirmedFight();
      await pumpDock(tester);
      await pumpFade(tester);

      final screen = tester.getRect(find.byType(Scaffold));
      final panel = tester.getRect(find.byType(BattleHud));
      expect(panel.left - screen.left, lessThan(24));
      expect(screen.right - panel.right, greaterThan(panel.left - screen.left));

      await drainIdleTimer(tester);
    });
    testWidgets('fades and grows in as the fight starts', (tester) async {
      await pumpDock(tester);
      feedConfirmedFight();

      // Mid-fade: partially transparent and only partially tall.
      await tester.pump();
      await tester.pump(BattleHudDock.fadeDuration ~/ 2);
      final midOpacity = dockOpacity(tester);
      final midHeight = tester.getSize(find.byType(BattleHudDock)).height;
      expect(midOpacity, greaterThan(0));
      expect(midOpacity, lessThan(1));
      expect(midHeight, greaterThan(0));

      await pumpFade(tester);
      expect(dockOpacity(tester), 1);
      expect(tester.getSize(find.byType(BattleHudDock)).height,
          greaterThan(midHeight));

      await drainIdleTimer(tester);
      await pumpFade(tester);
    });

    testWidgets('fades out and gives the space back when the fight ends',
        (tester) async {
      await pumpDock(tester);
      feedConfirmedFight();
      await pumpFade(tester);
      expect(tester.getSize(find.byType(BattleHudDock)).height, greaterThan(0));

      // Past the idle timeout the fight is over, so the panel leaves. The
      // outcome stays readable in the terminal — resolution lines are never
      // filtered — which is what makes removing it safe.
      await drainIdleTimer(tester);
      await pumpFade(tester);

      expect(dockOpacity(tester), 0);
      expect(tester.getSize(find.byType(BattleHudDock)).height, 0);
    });

    testWidgets('mounting mid-fight shows the panel without animating in',
        (tester) async {
      // Switching the mode on during combat shouldn't play a fade-in.
      feedConfirmedFight();
      await pumpDock(tester);

      expect(dockOpacity(tester), 1);

      await drainIdleTimer(tester);
      await pumpFade(tester);
    });
  });

  testWidgets('three-digit tallies fit beside the spelled-out labels',
      (tester) async {
    // The row overflowed by 0.25px once already, and "accuracy"/"evade" are
    // longer than the "acc"/"evd" it was tuned against. Worst case: 100+ of
    // everything on the narrowest screen.
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final lines = <String>[];
    for (var i = 0; i < 120; i++) {
      lines.add("You pounded Nurse's leg heartlessly.");
      lines.add('Nurse pounded your head heartlessly.');
      lines.add('You missed.');
      lines.add('Nurse missed you.');
    }
    feed(lines);
    await pumpHud(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('120% accuracy'), findsNothing, reason: 'sanity');
    expect(find.textContaining('accuracy'), findsOneWidget);
    expect(find.textContaining('evade'), findsOneWidget);

    await drainIdleTimer(tester);
  });

  group('pulse and clock', () {
    /// The border colour the HUD is currently painting.
    Color? borderColour(WidgetTester tester) {
      final box = tester.widgetList<Container>(find.descendant(
        of: find.byType(BattleHud),
        matching: find.byType(Container),
      )).first;
      return ((box.decoration as BoxDecoration).border as Border?)?.top.color;
    }

    testWidgets('the border pulses while a fight is running', (tester) async {
      feedConfirmedFight();
      await pumpHud(tester);

      // Compare whole colours: `Color.a` is a normalised double, so rounding it
      // to an int collapses every alpha in this range to 0.
      final samples = <Color>{};
      for (var i = 0; i < 6; i++) {
        await tester.pump(BattleHud.pulsePeriod ~/ 4);
        samples.add(borderColour(tester)!);
      }
      // Several distinct alphas over one period — a static border would give one.
      expect(samples.length, greaterThan(2));

      await drainIdleTimer(tester);
    });

    testWidgets('the pulse stops when the fight ends', (tester) async {
      feedConfirmedFight();
      await pumpHud(tester);
      await drainIdleTimer(tester);

      // Idle: no repeating animation, so the frame count settles. If the pulse
      // were still running this would time out.
      await tester.pumpAndSettle();
      final resting = borderColour(tester);
      await tester.pump(BattleHud.pulsePeriod);
      expect(borderColour(tester), resting);
    });

    testWidgets('the elapsed clock advances without new combat text',
        (tester) async {
      // The whole point of the local timer: a lull mid-fight used to freeze the
      // readout, because it only re-rendered when a line arrived. No further
      // combat text is fed here — only time passes.
      feedConfirmedFight();
      await pumpHud(tester);
      expect(find.textContaining('0:00'), findsOneWidget);

      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('0:03'), findsOneWidget);

      await drainIdleTimer(tester);
    });

    testWidgets('the clock stops when the fight does', (tester) async {
      feedConfirmedFight();
      await pumpHud(tester);
      await drainIdleTimer(tester);

      final frozen = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(BattleHud),
            matching: find.byType(Text),
          ))
          .map((t) => t.data)
          .firstWhere((s) => s != null && s.contains(':'));

      // No pending timer to advance it, so time passing changes nothing — and
      // reaching the end of the test with one scheduled would fail the run.
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(
        tester
            .widgetList<Text>(find.descendant(
              of: find.byType(BattleHud),
              matching: find.byType(Text),
            ))
            .map((t) => t.data),
        contains(frozen),
      );
    });
  });
}