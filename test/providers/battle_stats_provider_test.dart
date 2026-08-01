import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/battle_stats.dart';
import 'package:ancient_anguish_client/providers/battle_stats_provider.dart';
import 'package:ancient_anguish_client/services/parser/battle_text_classifier.dart';

void main() {
  late ProviderContainer container;
  late BattleStatsNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(battleStatsProvider.notifier);
  });

  tearDown(() => container.dispose());

  /// Feeds a raw combat line through the classifier into the notifier, exactly
  /// as `TerminalBufferNotifier` does — as a continuation of the round in
  /// progress, so the tallies can be exercised without also moving the round
  /// counter. See [feedRound] for the other half.
  void feed(String line) {
    final match = BattleTextClassifier.classify(line);
    expect(match, isNotNull, reason: 'Test fixture must classify: "$line"');
    notifier.record(match!, rawLine: line);
  }

  /// Feeds one batch of MUD output — the unit the client counts as a round.
  void feedRound(Iterable<String> lines) {
    var first = true;
    for (final line in lines) {
      final match = BattleTextClassifier.classify(line);
      expect(match, isNotNull, reason: 'Test fixture must classify: "$line"');
      notifier.record(match!, rawLine: line, startsRound: first);
      first = false;
    }
  }

  group('BattleStatsNotifier - tallies', () {
    test('starts empty and inactive', () {
      final stats = container.read(battleStatsProvider);
      expect(stats.active, isFalse);
      expect(stats.startedAt, isNull);
      expect(stats.rounds, 0);
      expect(stats.accuracy, isNull);
      expect(stats.evasion, isNull);
    });

    test('counts the reference transcript correctly', () {
      const transcript = [
        "Mummy pierced Nurse's head keenly.",
        "You pounded Nurse's leg heartlessly.",
        'Nurse missed you.',
        "Mummy pricked Nurse's head.",
        "You pounded Nurse's head heartlessly.",
        "You duck your head quickly as Nurse's blow flies over you.",
        'Nurse missed you.',
        "Mummy lacerated Nurse's body.",
        'You missed.',
        'HP:  88  SP:  79',
        'Nurse pounded your head heartlessly.',
        "Mummy impaled Nurse's body sharply.",
        "You pounded Nurse's body heartlessly.",
        'HP:  83  SP:  79',
        'Nurse pounded your body heartlessly.',
        'Mummy missed Nurse.',
        'You missed.',
        'HP:  82  SP:  79',
        'Nurse battered your leg.',
        "Mummy pricked Nurse's head.",
        'Nurse died.',
        'You killed Nurse.',
      ];
      for (final line in transcript) {
        feed(line);
      }

      final stats = container.read(battleStatsProvider);
      expect(stats.active, isTrue);
      expect(stats.target, 'Nurse');
      // Three "You pounded Nurse's <part>" lines, two "You missed."
      expect(stats.hitsDealt, 3);
      expect(stats.missesDealt, 2);
      // "Nurse pounded your head/body", "Nurse battered your leg".
      expect(stats.hitsTaken, 3);
      // Two "Nurse missed you." plus the duck.
      expect(stats.missesAgainst, 3);
      expect(stats.otherHits, 5);
      expect(stats.otherMisses, 1);
      // "Nurse died." and "You killed Nurse."
      expect(stats.resolutions, 2);
      // The whole transcript arrived as one batch, so it is one round — the
      // three `HP:/SP:` lines set the vitals but no longer drive the counter.
      expect(stats.rounds, 0, reason: 'feed() continues the round in progress');
      expect(stats.latestLine, 'You killed Nurse.');
    });

    test('derives accuracy, evasion and HP lost', () {
      feed("You pounded Nurse's leg heartlessly.");
      feed("You pounded Nurse's head heartlessly.");
      feed("You pounded Nurse's body heartlessly.");
      feed('You missed.');
      feed('HP:  88  SP:  79');
      feed('Nurse pounded your head heartlessly.');
      feed('Nurse missed you.');
      feed('HP:  82  SP:  75');

      final stats = container.read(battleStatsProvider);
      expect(stats.accuracy, 75); // 3 of 4
      expect(stats.evasion, 50); // 1 of 2
      expect(stats.hpStart, 88); // first reading, not the latest
      expect(stats.hpNow, 82);
      expect(stats.spNow, 75);
      expect(stats.hpLost, 6);
    });

    test('healing outpacing damage reports a negative loss', () {
      feed('HP:  40  SP:  20');
      feed('Nurse missed you.');
      feed('HP:  60  SP:  20');
      expect(container.read(battleStatsProvider).hpLost, -20);
    });

    test('keeps the last named opponent when a line names nobody', () {
      feed("You pounded Nurse's leg heartlessly.");
      feed('You missed.');
      expect(container.read(battleStatsProvider).target, 'Nurse');
    });

    test('a kill does not end the fight — a pulled group is one fight', () {
      feed("You pounded Nurse's leg heartlessly.");
      feed('You killed Nurse.');
      feed("You pounded Mummy's leg heartlessly.");

      final stats = container.read(battleStatsProvider);
      expect(stats.active, isTrue);
      expect(stats.resolutions, 1);
      expect(stats.hitsDealt, 2, reason: 'Tallies carry across the kill.');
      expect(stats.target, 'Mummy');
    });
  });

  group('BattleStatsNotifier - rounds', () {
    test('counts one round per batch of output, not per vitals line', () {
      // Two batches, three vitals lines between them. Counting the vitals lines
      // is what this used to do, and it read the fight as three rounds — while
      // in live play, where AA rarely prints a bare `HP:/SP:` line at all, it
      // read the same fight as none.
      feedRound([
        "You pounded Nurse's leg heartlessly.",
        'HP:  88  SP:  79',
        'HP:  87  SP:  79',
      ]);
      feedRound(['Nurse missed you.', 'HP:  86  SP:  79']);

      final stats = container.read(battleStatsProvider);
      expect(stats.rounds, 2);
      expect(stats.hpStart, 88, reason: 'vitals still set the readings');
      expect(stats.hpNow, 86);
    });

    test('a fight is unconfirmed until enough rounds have arrived', () {
      for (var i = 1; i < BattleStats.confirmRounds; i++) {
        feedRound(['Nurse missed you.']);
        expect(container.read(battleStatsProvider).confirmed, isFalse,
            reason: 'round $i of ${BattleStats.confirmRounds}');
      }

      feedRound(['Nurse missed you.']);
      expect(container.read(battleStatsProvider).confirmed, isTrue);
    });

    test('the next fight has to earn its confirmation again', () {
      fakeAsync((async) {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final n = c.read(battleStatsProvider.notifier);
        final match = BattleTextClassifier.classify('Nurse missed you.')!;

        for (var i = 0; i < BattleStats.confirmRounds; i++) {
          n.record(match, startsRound: true);
        }
        expect(c.read(battleStatsProvider).confirmed, isTrue);

        async.elapse(BattleStatsNotifier.battleTimeout * 2);
        n.record(match, startsRound: true);

        expect(c.read(battleStatsProvider).rounds, 1);
        expect(c.read(battleStatsProvider).confirmed, isFalse);
      });
    });
  });

  group('BattleStatsNotifier - fight lifecycle', () {
    test('goes inactive after the timeout but stays readable', () {
      fakeAsync((async) {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final n = c.read(battleStatsProvider.notifier);

        n.record(
          BattleTextClassifier.classify("You pounded Nurse's leg heartlessly.")!,
          rawLine: "You pounded Nurse's leg heartlessly.",
        );
        expect(c.read(battleStatsProvider).active, isTrue);

        async.elapse(BattleStatsNotifier.battleTimeout + const Duration(seconds: 1));

        final stats = c.read(battleStatsProvider);
        expect(stats.active, isFalse);
        // The point of freezing rather than clearing: a glance right after the
        // kill still shows how the fight went.
        expect(stats.hitsDealt, 1);
        expect(stats.target, 'Nurse');
        expect(stats.latestLine, isNotNull);
      });
    });

    test('activity before the timeout keeps one fight alive', () {
      fakeAsync((async) {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final n = c.read(battleStatsProvider.notifier);
        final match =
            BattleTextClassifier.classify("You pounded Nurse's leg heartlessly.")!;

        n.record(match);
        async.elapse(BattleStatsNotifier.battleTimeout - const Duration(seconds: 1));
        n.record(match);
        async.elapse(BattleStatsNotifier.battleTimeout - const Duration(seconds: 1));

        final stats = c.read(battleStatsProvider);
        expect(stats.active, isTrue);
        expect(stats.hitsDealt, 2, reason: 'Same fight, not two fights.');
      });
    });

    test('the next fight starts from zero', () {
      fakeAsync((async) {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final n = c.read(battleStatsProvider.notifier);

        n.record(BattleTextClassifier.classify("You pounded Nurse's leg heartlessly.")!);
        n.record(BattleTextClassifier.classify('HP:  88  SP:  79')!);
        async.elapse(BattleStatsNotifier.battleTimeout * 2);

        n.record(BattleTextClassifier.classify("Guard pounded your head heartlessly.")!);

        final stats = c.read(battleStatsProvider);
        expect(stats.active, isTrue);
        expect(stats.hitsDealt, 0, reason: 'Previous fight must not carry over.');
        expect(stats.hitsTaken, 1);
        expect(stats.rounds, 0);
        expect(stats.hpStart, isNull);
        expect(stats.target, 'Guard');
      });
    });

    test('reset clears everything', () {
      feed("You pounded Nurse's leg heartlessly.");
      notifier.reset();

      final stats = container.read(battleStatsProvider);
      expect(stats.active, isFalse);
      expect(stats.hitsDealt, 0);
      expect(stats.target, isNull);
      expect(stats.startedAt, isNull);
    });
  });
}
