import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/parser/battle_text_classifier.dart';

/// The real transcript this feature was built from: the player and a Mummy
/// (pet/party member) fighting a Nurse to the death. Every line here must
/// classify, or combat spam leaks into the buffer under both filter modes.
const _transcript = [
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

void main() {
  group('BattleTextClassifier - the reference transcript', () {
    test('classifies every line', () {
      for (final line in _transcript) {
        expect(
          BattleTextClassifier.classify(line),
          isNotNull,
          reason: 'Unclassified combat line: "$line"',
        );
      }
    });

    test('names the opponent on every line that mentions one', () {
      // `You missed.` is the only line in the transcript that names nobody.
      for (final line in _transcript.where((l) => l != 'You missed.')) {
        final match = BattleTextClassifier.classify(line)!;
        if (match.kind == BattleLineKind.vitals) continue;
        expect(match.opponent, 'Nurse', reason: 'From "$line"');
      }
    });

    test('only the two resolution lines survive filtering', () {
      final unfiltered = _transcript
          .where((l) => !BattleTextClassifier.classify(l)!.isFilterable)
          .toList();
      expect(unfiltered, ['Nurse died.', 'You killed Nurse.']);
    });
  });

  group('BattleTextClassifier.classify - hits', () {
    test('your hit on a named creature', () {
      final match =
          BattleTextClassifier.classify("You pounded Nurse's leg heartlessly.")!;
      expect(match.kind, BattleLineKind.yourHit);
      expect(match.opponent, 'Nurse');
      expect(match.involvesPlayer, isTrue);
    });

    test('a creature hitting you', () {
      final match =
          BattleTextClassifier.classify('Nurse pounded your head heartlessly.')!;
      expect(match.kind, BattleLineKind.incomingHit);
      expect(match.opponent, 'Nurse');
    });

    test('a third party hitting the target', () {
      final match =
          BattleTextClassifier.classify("Mummy pierced Nurse's head keenly.")!;
      expect(match.kind, BattleLineKind.otherHit);
      expect(match.opponent, 'Nurse');
      expect(match.involvesPlayer, isFalse);
    });

    test('adverb is optional', () {
      expect(
        BattleTextClassifier.classify("Mummy pricked Nurse's head.")?.kind,
        BattleLineKind.otherHit,
      );
    });

    test('an unknown damage verb still classifies (structure, not lexicon)', () {
      // "skewered" appears in no list anywhere in the client.
      final match = BattleTextClassifier.classify(
          "You skewered Nurse's thigh gruesomely.")!;
      expect(match.kind, BattleLineKind.yourHit);
      expect(match.opponent, 'Nurse');
    });

    test('laterality in front of the body part', () {
      expect(
        BattleTextClassifier.classify('Nurse battered your left arm.')?.kind,
        BattleLineKind.incomingHit,
      );
      expect(
        BattleTextClassifier.classify("You clawed Nurse's hind leg.")?.kind,
        BattleLineKind.yourHit,
      );
    });

    test('multi-word creature names', () {
      final match = BattleTextClassifier.classify(
          'The city guard pounded your shoulder heartlessly.')!;
      expect(match.kind, BattleLineKind.incomingHit);
      expect(match.opponent, 'city guard');
    });

    test('a body part that is not anatomy is not a hit', () {
      expect(
        BattleTextClassifier.classify("You pounded Nurse's reputation soundly."),
        isNull,
      );
    });
  });

  group('BattleTextClassifier.classify - misses', () {
    test('your bare miss names nobody', () {
      final match = BattleTextClassifier.classify('You missed.')!;
      expect(match.kind, BattleLineKind.yourMiss);
      expect(match.opponent, isNull);
    });

    test('your miss on a named target', () {
      final match = BattleTextClassifier.classify('You missed Nurse.')!;
      expect(match.kind, BattleLineKind.yourMiss);
      expect(match.opponent, 'Nurse');
    });

    test('a creature missing you', () {
      final match = BattleTextClassifier.classify('Nurse missed you.')!;
      expect(match.kind, BattleLineKind.incomingMiss);
      expect(match.opponent, 'Nurse');
    });

    test('a third party missing the target', () {
      final match = BattleTextClassifier.classify('Mummy missed Nurse.')!;
      expect(match.kind, BattleLineKind.otherMiss);
      expect(match.opponent, 'Nurse');
    });
  });

  group('BattleTextClassifier.classify - evasion', () {
    test('your dodge reads as an incoming miss, not a hit on you', () {
      // This line also satisfies the hit skeleton ("You duck your head …"),
      // which is why evasion is matched first. Getting it wrong would score a
      // successful dodge as damage taken.
      final match = BattleTextClassifier.classify(
          "You duck your head quickly as Nurse's blow flies over you.")!;
      expect(match.kind, BattleLineKind.incomingMiss);
      expect(match.opponent, 'Nurse');
    });

    test('a creature dodging your attack reads as your miss', () {
      final match =
          BattleTextClassifier.classify('Nurse dodges your attack.')!;
      expect(match.kind, BattleLineKind.yourMiss);
      expect(match.opponent, 'Nurse');
    });

    test('a creature dodging a third party reads as a third-party miss', () {
      final match =
          BattleTextClassifier.classify("Nurse parries Mummy's attack.")!;
      expect(match.kind, BattleLineKind.otherMiss);
    });
  });

  group('BattleTextClassifier.classify - vitals', () {
    test('parses HP and SP', () {
      final match = BattleTextClassifier.classify('HP:  88  SP:  79')!;
      expect(match.kind, BattleLineKind.vitals);
      expect(match.hp, 88);
      expect(match.sp, 79);
    });

    test('a line carrying content plus vitals is not a vitals line', () {
      // Gagging this would take real output with it. `BattleNotifier`'s looser
      // regex deliberately still matches it for battle *detection*.
      expect(
        BattleTextClassifier.classify('You feel weak. HP:  88  SP:  79')?.kind,
        isNot(BattleLineKind.vitals),
      );
    });
  });

  group('BattleTextClassifier.classify - resolution', () {
    test('a creature dying is never filterable', () {
      final match = BattleTextClassifier.classify('Nurse died.')!;
      expect(match.kind, BattleLineKind.resolution);
      expect(match.opponent, 'Nurse');
      expect(match.isFilterable, isFalse);
    });

    test('your kill', () {
      final match = BattleTextClassifier.classify('You killed Nurse.')!;
      expect(match.kind, BattleLineKind.resolution);
      expect(match.opponent, 'Nurse');
    });

    test('your own death', () {
      expect(
        BattleTextClassifier.classify('You died.')?.kind,
        BattleLineKind.resolution,
      );
    });

    test('"is dead" phrasing', () {
      expect(
        BattleTextClassifier.classify('Nurse is dead.')?.kind,
        BattleLineKind.resolution,
      );
    });
  });

  group('BattleTextClassifier.classify - non-combat output', () {
    // Each of these would be collapsed or gagged if it classified, so they are
    // the lines that keep the filter honest.
    const notCombat = [
      'You see a forest.',
      'The path leads east.',
      'A giant eagle.',
      'An ugly-looking fierce Troll',
      'Grubby Hollow (n,e,sw)',
      '[HP:88 SP:79]',
      'Nurse tells you: hello there',
      '[Chat] Tuinn: anyone up for a hunt?',
      'You are now following Mummy.',
      'Mummy arrives.',
      'You have 42 gold coins.',
      'Obvious exits: north, east and southwest.',
      '',
      '   ',
    ];

    for (final line in notCombat) {
      test('ignores "$line"', () {
        expect(BattleTextClassifier.classify(line), isNull);
      });
    }
  });
  group("Sami's Ship rat transcript (multi-word creature names)", () {
    // The whole transcript was reaching the terminal unfiltered: `_possessive`
    // only matched a single-word name, so no `Ship rat's <part>` line
    // classified while the identical `Nurse's <part>` line did. Every
    // two-word creature in the game was affected.
    const yourHits = [
      "You slit Ship rat's body.",
      "You chopped Ship rat's body bluntly.",
      "You sliced Ship rat's paw deeply.",
      "You clubbed Ship rat's body.",
      "You gashed Ship rat's body.",
      "You pounded Ship rat's body heartlessly.",
      "You sliced Ship rat's body deeply.",
      "You pierced Ship rat's body keenly.",
      "You chopped Ship rat's head bluntly.",
      "You lacerated Ship rat's head.",
    ];

    for (final line in yourHits) {
      test('reads "$line" as your hit on Ship rat', () {
        final match = BattleTextClassifier.classify(line);
        expect(match?.kind, BattleLineKind.yourHit);
        expect(match?.opponent, 'Ship rat');
      });
    }

    test('a three-word creature name works too', () {
      // Capitalised, because that is how AA renders a creature's short
      // description in combat output — the possessive deliberately requires it
      // rather than matching any lowercase noun phrase, which is what keeps
      // prose out.
      final match =
          BattleTextClassifier.classify("You slit City guard captain's arm.");
      expect(match?.kind, BattleLineKind.yourHit);
      expect(match?.opponent, 'City guard captain');
    });

    test('a lowercase noun phrase is still not a creature', () {
      expect(
        BattleTextClassifier.classify("You slit the old city guard's arm."),
        isNull,
      );
    });

    test('footwork counts as an evasion, not a hit', () {
      // `take a quick step backwards` also satisfies the hit skeleton
      // (actor + verb + possessive + noun), so ordering matters here.
      final match = BattleTextClassifier.classify(
          "You take a quick step backwards, avoiding Ship rat's attack.");
      expect(match?.kind, BattleLineKind.incomingMiss);
      expect(match?.opponent, 'Ship rat');
    });

    test('footwork against a single-word creature too', () {
      final match = BattleTextClassifier.classify(
          "You take a quick step backwards, avoiding Zombie's attack.");
      expect(match?.kind, BattleLineKind.incomingMiss);
      expect(match?.opponent, 'Zombie');
    });

    test('a read dodge is filterable chatter that scores nothing', () {
      // Neither a hit nor a successful evasion — counting it as either would
      // put a number in the HUD for an exchange that never happened.
      final match =
          BattleTextClassifier.classify('Ship rat predicts your attempt to dodge!');
      expect(match?.kind, BattleLineKind.flavour);
      expect(match?.isFilterable, isTrue);
      expect(match?.opponent, isNull);
    });

    test('a read dodge from a single-word creature', () {
      expect(
        BattleTextClassifier.classify('Zombie predicts your attempt to dodge!')
            ?.kind,
        BattleLineKind.flavour,
      );
    });

    test('the passive death line resolves, naming the creature cleanly', () {
      // Greedy actor matching read this as actor `Ship rat is` + verb
      // `vanquished` — a plausible-looking name with a stray word welded on.
      final match = BattleTextClassifier.classify('Ship rat is vanquished.');
      expect(match?.kind, BattleLineKind.resolution);
      expect(match?.opponent, 'Ship rat');
    });

    test('the active kill line resolves', () {
      final match = BattleTextClassifier.classify('You vanquished Ship rat.');
      expect(match?.kind, BattleLineKind.resolution);
      expect(match?.opponent, 'Ship rat');
      expect(match?.isFilterable, isFalse);
    });
  });

  group('lines that must stay non-combat after the loosening', () {
    // The multi-word possessive, the footwork shape and the flavour idiom each
    // widened a pattern; these are the neighbours they must not swallow.
    const notCombat = [
      'You take a step towards the gate.',
      'The wizard predicts your future.',
      'A ship rat is standing here.',
      "You admire Ship rat's shiny collar.",
      'You take a quick step backwards, admiring the view.',
      "Nurse tells you: I slit Ship rat's body.",
    ];

    for (final line in notCombat) {
      test('ignores "$line"', () {
        expect(BattleTextClassifier.classify(line), isNull);
      });
    }
  });
}