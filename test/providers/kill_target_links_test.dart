import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/providers/kill_target_links_provider.dart';
import 'package:ancient_anguish_client/providers/room_targets_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StyledLine plain(String text) => StyledLine([StyledSpan(text: text)]);

  /// The (text, command) pairs of every command-bearing span in [line].
  List<(String, String)> links(StyledLine line) => [
        for (final s in line.spans)
          if (s.command != null) (s.text, s.command!),
      ];

  group('kill-target links', () {
    test('promotes a catalogue target to a kill link', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('A large goblin blocks the path.'));

      expect(links(out), [('goblin', 'kill goblin')]);
    });

    test('tints the promoted span reddish and leaves the rest alone', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('An orc waits.'));

      final link = out.spans.firstWhere((s) => s.command != null);
      expect(link.foreground, killTargetLinkColor);
      for (final s in out.spans.where((s) => s.command == null)) {
        expect(s.foreground, isNot(killTargetLinkColor));
      }
    });

    test('matches case-insensitively but sends the word as written', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('Troll here.'));

      expect(links(out), [('Troll', 'kill Troll')]);
    });

    test('respects word boundaries', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // "catalogue" contains "cat", "birdsong" contains "bird" — neither
      // should become a link.
      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('The catalogue hums with birdsong.'));

      expect(links(out), isEmpty);
    });

    test('picks up NPCs detected in the current room', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Drive the room parser: header, an NPC line, then a blank line to
      // commit the block.
      final rooms = container.read(roomTargetsProvider.notifier);
      for (final line in [
        'Dusty Crossroads (n,e,sw)',
        'A grizzled mercenary.',
        '',
      ]) {
        rooms.processLine(line);
      }
      expect(container.read(roomTargetsProvider), contains('mercenary'));

      final out = container
          .read(killTargetLinkProcessorProvider)
          .processLine(plain('The mercenary spits.'));

      expect(links(out), [('mercenary', 'kill mercenary')]);
    });

    test('leaves a span that already carries a command untouched', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

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
  });
}
