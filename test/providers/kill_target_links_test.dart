import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/providers/kill_target_links_provider.dart';
import 'package:ancient_anguish_client/providers/room_targets_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/services/parser/kill_target_link_processor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StyledLine plain(String text) => StyledLine([StyledSpan(text: text)]);

  /// The (text, command) pairs of every command-bearing span in [line].
  List<(String, String)> links(StyledLine line) => [
        for (final s in line.spans)
          if (s.command != null) (s.text, s.command!),
      ];

  /// Runs [block] through the room parser the way the terminal does — one
  /// line at a time, linking each as it arrives with whatever keyword the
  /// parser extracted from it. Returns the links found on the last line.
  List<(String, String)> linksAfterBlock(
    ProviderContainer container,
    List<String> block,
  ) {
    final rooms = container.read(roomTargetsProvider.notifier);
    var result = <(String, String)>[];
    for (final text in block) {
      final keyword = rooms.processLine(text);
      final processor = container.read(killTargetLinkProcessorProvider);
      result = links(processor.processLine(plain(text), npcKeyword: keyword));
    }
    return result;
  }

  ProviderContainer freshContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group("Sami's reported false positives", () {
    test('a door is not a kill target', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Dusty Crossroads (n,e,sw)',
          'A shimmering blue door.',
        ]),
        isEmpty,
      );
    });

    test('an urn is not a kill target', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Dusty Crossroads (n,e,sw)',
          'A large white urn.',
        ]),
        isEmpty,
      );
    });

    test('a board is not a kill target', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Dusty Crossroads (n,e,sw)',
          'The Paladin Board.',
        ]),
        isEmpty,
      );
    });

    test('a room header never contains kill targets', () {
      expect(
        linksAfterBlock(freshContainer(), ['West Gate (e,w)']),
        isEmpty,
      );
    });

    test('a signpost is not a kill target', () {
      // Found while shooting the demo scene: `sign` was blocked but the
      // compound `signpost` sailed through and rendered a red kill link.
      expect(
        linksAfterBlock(freshContainer(), [
          'Snag creek bridge (n,e,w)',
          'A weathered signpost.',
        ]),
        isEmpty,
      );
    });

    test('a corpse is not a kill target', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Snag creek bridge (n,e,w)',
          'The rotting corpse.',
        ]),
        isEmpty,
      );
    });

    test('an announcement links the creature, not its adjective', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Light pine forest (n,e,s)',
          'A giant eagle.',
        ]),
        [('eagle', 'kill eagle')],
      );
    });
  });

  group('article announcements — `A/An <adjectives> <target>`', () {
    /// The three shapes Sami reported. All arrive *without* a trailing
    /// period, which is how Ancient Anguish prints most short descriptions.
    test('A forest Hare → hare', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Light pine forest (n,e,s)',
          'A forest Hare',
        ]),
        [('Hare', 'kill hare')],
      );
    });

    test('A giant eagle → eagle', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Light pine forest (n,e,s)',
          'A giant eagle',
        ]),
        [('eagle', 'kill eagle')],
      );
    });

    test('An ugly-looking fierce Troll → troll', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Dark cavern (n,e)',
          'An ugly-looking fierce Troll',
        ]),
        [('Troll', 'kill troll')],
      );
    });

    test('adjectives are not capped — a five-word phrase still resolves', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Dark cavern (n,e)',
          'An ugly-looking fierce mountain Troll',
        ]),
        [('Troll', 'kill troll')],
      );
    });

    test('a comma between adjectives does not derail the head noun', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Dusty Crossroads (n,e,sw)',
          'A tall, thin man',
        ]),
        [('man', 'kill man')],
      );
    });
  });

  group('article announcements that are really sentences', () {
    test('a trailing verb is not a target', () {
      // Before the verb guard this rendered a red `kill arrives` link.
      expect(
        linksAfterBlock(freshContainer(), [
          'Light pine forest (n,e,s)',
          'A goblin arrives.',
        ]),
        // `goblin` is in the static catalogue, so the line still offers the
        // creature — just never the verb.
        [('goblin', 'kill goblin')],
      );
    });

    test('a prepositional phrase is not a target', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Light pine forest (n,e,s)',
          'A wolf howls in the distance',
        ]),
        isEmpty,
      );
    });

    test('an adverb is not a target', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Light pine forest (n,e,s)',
          'The eagle circles overhead slowly',
        ]),
        isEmpty,
      );
    });

    test('scenery still loses even without a trailing period', () {
      expect(
        linksAfterBlock(freshContainer(), [
          'Snag creek bridge (n,e,w)',
          'A weathered signpost',
        ]),
        isEmpty,
      );
    });
  });

  group('room-target detection', () {
    test('scenery never reaches the Kill picker either', () {
      final container = freshContainer();
      final rooms = container.read(roomTargetsProvider.notifier);
      for (final line in [
        'Dusty Crossroads (n,e,sw)',
        'A shimmering blue door.',
        'A large white urn.',
        'The Paladin Board.',
        'A grizzled mercenary.',
        '',
      ]) {
        rooms.processLine(line);
      }
      expect(container.read(roomTargetsProvider), ['mercenary']);
    });
  });

  group('catalogue scan (lines with no announcement keyword)', () {
    test('promotes a catalogue target in prose', () {
      final container = freshContainer();
      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('The goblin hits you.'));
      expect(links(out), [('goblin', 'kill goblin')]);
    });

    test('tints the promoted span reddish and leaves the rest alone', () {
      final container = freshContainer();
      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('The orc snarls at you.'));

      final link = out.spans.firstWhere((s) => s.command != null);
      expect(link.foreground, killTargetLinkColor);
      for (final s in out.spans.where((s) => s.command == null)) {
        expect(s.foreground, isNot(killTargetLinkColor));
      }
    });

    test('matches case-insensitively and sends a lower-cased command', () {
      final container = freshContainer();
      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('Troll blocks your way.'));
      expect(links(out), [('Troll', 'kill troll')]);
    });

    test('adjacent catalogue words collapse to the head noun', () {
      // Both "giant" and "orc" are catalogue entries; only the noun links.
      final container = freshContainer();
      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('The giant orc swings wildly.'));
      expect(links(out), [('orc', 'kill orc')]);
    });

    test('respects word boundaries', () {
      final container = freshContainer();
      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('The catalogue hums with birdsong.'));
      expect(links(out), isEmpty);
    });

    test('leaves a span that already carries a command untouched', () {
      final container = freshContainer();
      final preLinked = StyledLine([
        const StyledSpan(text: 'The '),
        const StyledSpan(text: 'goblin', command: 'greet goblin'),
        const StyledSpan(text: ' nods.'),
      ]);
      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(preLinked);
      expect(links(out), [('goblin', 'greet goblin')]);
    });

    test('a prompt line is never scanned', () {
      final container = freshContainer();
      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('[HP: 120/140 SP: 80/90 orc]'));
      expect(links(out), isEmpty);
    });
  });

  group('KillTargetLinkProcessor with no catalogue', () {
    test('is empty and still links an announcement keyword', () {
      final processor = KillTargetLinkProcessor(const []);
      expect(processor.isEmpty, isTrue);
      final out =
          processor.processLine(plain('A giant eagle.'), npcKeyword: 'eagle');
      expect(links(out), [('eagle', 'kill eagle')]);
    });
  });

  group('user ignore list', () {
    test('mutes a catalogue word', () {
      final processor = KillTargetLinkProcessor(
        const ['goblin', 'orc'],
        ignored: const ['goblin'],
      );
      expect(
        links(processor.processLine(plain('The goblin hits you.'))),
        isEmpty,
      );
      expect(
        links(processor.processLine(plain('The orc hits you.'))),
        [('orc', 'kill orc')],
      );
    });

    test('mutes an announcement keyword too', () {
      // The announcement path bypasses the catalogue entirely, so filtering
      // the alternation alone would leave the red link on the very line that
      // introduced the creature.
      final processor = KillTargetLinkProcessor(
        const ['eagle'],
        ignored: const ['eagle'],
      );
      expect(
        links(
          processor.processLine(plain('A giant eagle.'), npcKeyword: 'eagle'),
        ),
        isEmpty,
      );
    });

    test('normalizes case and surrounding whitespace', () {
      final processor = KillTargetLinkProcessor(
        const ['troll'],
        ignored: const ['  TROLL '],
      );
      expect(
        links(processor.processLine(plain('Troll blocks your way.'))),
        isEmpty,
      );
      expect(
        links(processor.processLine(plain('A troll.'), npcKeyword: 'Troll')),
        isEmpty,
      );
    });

    test('the settings ignore list reaches the wired-up processor', () {
      final container = freshContainer();
      expect(
        links(
          container
              .read(killTargetLinkProcessorProvider)
              .processLine(plain('The goblin hits you.')),
        ),
        [('goblin', 'kill goblin')],
      );

      container.read(settingsProvider.notifier).addIgnoredKillTarget('Goblin');
      expect(
        links(
          container
              .read(killTargetLinkProcessorProvider)
              .processLine(plain('The goblin hits you.')),
        ),
        isEmpty,
      );

      container
          .read(settingsProvider.notifier)
          .removeIgnoredKillTarget('goblin');
      expect(
        links(
          container
              .read(killTargetLinkProcessorProvider)
              .processLine(plain('The goblin hits you.')),
        ),
        [('goblin', 'kill goblin')],
      );
    });

    test('ignoring leaves the Kill picker targets alone', () {
      // "Don't paint this red" is not "I can never attack this".
      final container = freshContainer();
      final rooms = container.read(roomTargetsProvider.notifier);
      container.read(settingsProvider.notifier).addIgnoredKillTarget('eagle');
      // Trailing blank line closes the room block, which is when the picker's
      // target list commits.
      for (final line in ['Dusty Crossroads (n,e,sw)', 'A giant eagle.', '']) {
        rooms.processLine(line);
      }
      expect(container.read(roomTargetsProvider), contains('eagle'));
    });
  });
}
