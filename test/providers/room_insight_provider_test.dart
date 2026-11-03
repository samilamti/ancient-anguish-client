import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/room_insight.dart';
import 'package:ancient_anguish_client/providers/room_insight_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';

/// `kind: label (count)` + commands, one string per entity, so a room's
/// whole reading fits on one expect line.
List<String> _describe(RoomInsight room) => [
      for (final e in room.entities)
        '${e.kind.name}: ${e.label}${e.count == null ? '' : ' (${e.count})'}'
            ' | ${e.commands.join(', ')}',
    ];

RoomInsight _parse(String block) {
  final lines = block.split('\n');
  final room = RoomInsightParser.parseHeader(lines.first)!;
  final seen = <String, int>{};
  return RoomInsight(
    name: room.name,
    exits: room.exits,
    entities: [
      for (final l in lines.skip(1))
        ?RoomInsightParser.parseEntity(l, seen),
    ],
  );
}

void main() {
  group('RoomInsightParser', () {
    test('coins are a counted object', () {
      final room = _parse('Nice forest (n,e,s,w)\n29 gold coins.');
      expect(room.name, 'Nice forest');
      expect(room.exits, ['north', 'east', 'south', 'west']);
      expect(_describe(room), ['item: gold coins (29) | get coins, look at coins']);
    });

    test('single creatures', () {
      expect(_describe(_parse('Light forest (n,e,s,w)\nA raven.')),
          ['npc: raven | look at raven, kill raven']);
      expect(_describe(_parse('Dark but inviting forest (n,e,s,w)\nA small fawn.')),
          ['npc: fawn | look at fawn, kill fawn']);
    });

    test('duplicates get an ordinal', () {
      final room = _parse(
          'Nice forest (n,e,s,w)\nA green frog.\nA green frog.\nA small hound.');
      expect(_describe(room), [
        'npc: frog | look at frog, kill frog',
        'npc: frog 2 | look at frog 2, kill frog 2',
        'npc: hound | look at hound, kill hound',
      ]);
    });

    test('a branch is an object, nw is northwest', () {
      final room = _parse('Pine forest (n,e,s,nw)\nA giant tick.\nA strong branch.');
      expect(room.exits, ['north', 'east', 'south', 'northwest']);
      expect(_describe(room), [
        'npc: tick | look at tick, kill tick',
        'item: branch | get branch, look at branch',
      ]);
    });

    test('an edible object and an "of" phrase', () {
      final room = _parse(
          'Forest with leftovers (n,e)\nA sugar crystal.\nAn army of five ants.');
      expect(room.exits, ['north', 'east']);
      expect(_describe(room), [
        'edible: crystal | get crystal, eat crystal',
        'npc: army | look at army, kill army',
      ]);
    });

    test('fixtures are looked at, not picked up', () {
      final room = _parse('Light pine forest (n,e,s)\n'
          'A thin mist drifts between the trunks to the north.\n'
          'A shimmering blue door.\nA weathered signpost.\nA giant eagle.');
      expect(_describe(room), [
        'misc: door | look at door, open door',
        'misc: signpost | look at signpost, read signpost',
        'npc: eagle | look at eagle, kill eagle',
      ]);
    });

    test('a room-unique thing defaults to NPC until the player refiles it',
        () {
      final room = _parse(
          "Forest (e,s,w,ne)\nA wasps' nest.\nA swarm of five wasps.");
      expect(room.exits, ['east', 'south', 'west', 'northeast']);
      expect(_describe(room), [
        'npc: nest | look at nest, kill nest',
        'npc: swarm | look at swarm, kill swarm',
      ]);
      expect(room.entities.first.phrase, 'wasps nest');

      final refiled = room.withOverrides({'wasps nest': RoomEntityKind.misc});
      expect(_describe(refiled), [
        'misc: nest | look at nest',
        'npc: swarm | look at swarm, kill swarm',
      ]);
      expect(refiled.entities.first.isOverridden, isTrue);
      expect(refiled.entities.first.autoKind, RoomEntityKind.npc);
    });

    test('every kind has its own commands', () {
      final e = RoomInsightParser.parseEntity('A long sword.', {})!;
      expect(e.kind, RoomEntityKind.item);
      expect(e.withKind(RoomEntityKind.edible).commands,
          ['get sword', 'eat sword']);
      expect(RoomInsightParser.parseEntity('Some ale.', {})!.commands,
          ['get ale', 'drink ale']);
      expect(RoomInsightParser.parseEntity('A red apple.', {})!.kind,
          RoomEntityKind.edible);
    });

    test('prose and player lines list nothing', () {
      final seen = <String, int>{};
      expect(RoomInsightParser.parseEntity('The path leads east.', seen), isNull);
      expect(RoomInsightParser.parseEntity('A wolf howls in the distance.', seen),
          isNull);
      expect(RoomInsightParser.parseEntity('Tuinn the Wizard', seen), isNull);
      expect(RoomInsightParser.parseHeader('You hit the orc.'), isNull);
    });
  });

  group('roomInsightViewProvider', () {
    test('applies the recategorisation stored in settings', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        final n = container.read(roomInsightProvider.notifier);
        for (final l in ['Forest (e,s,w,ne)', "A wasps' nest.", '']) {
          n.processLine(l);
        }
        async.elapse(const Duration(seconds: 1));
        expect(container.read(roomInsightViewProvider)!.entities.single.kind,
            RoomEntityKind.npc);

        final settings = container.read(settingsProvider.notifier);
        settings.setRoomEntityKind('wasps nest', 'misc');
        expect(container.read(roomInsightViewProvider)!.entities.single.kind,
            RoomEntityKind.misc);

        settings.setRoomEntityKind('wasps nest', null);
        expect(container.read(roomInsightViewProvider)!.entities.single.kind,
            RoomEntityKind.npc);
        async.flushMicrotasks();
        container.dispose();
      });
    });

    test('settings round-trip the choices', () {
      final json = const AppSettings(roomEntityKinds: {'wasps nest': 'misc'})
          .toJson();
      expect(AppSettings.fromJson(json).roomEntityKinds, {'wasps nest': 'misc'});
      expect(AppSettings.fromJson(const {}).roomEntityKinds, isEmpty);
    });
  });

  group('RoomInsightNotifier', () {
    test('a room shows after the settle delay, rooms passed through never do',
        () {
      fakeAsync((async) {
        final container = ProviderContainer();
        final n = container.read(roomInsightProvider.notifier);

        for (final l in ['Light forest (n,e,s,w)', 'A raven.', '']) {
          n.processLine(l);
        }
        async.elapse(const Duration(milliseconds: 500));
        expect(container.read(roomInsightProvider), isNull);

        for (final l in ['Pine forest (n,e,s,nw)', 'A giant tick.', '']) {
          n.processLine(l);
        }
        async.elapse(const Duration(milliseconds: 900));
        expect(container.read(roomInsightProvider), isNull);

        async.elapse(const Duration(milliseconds: 200));
        final room = container.read(roomInsightProvider)!;
        expect(room.name, 'Pine forest');
        expect(room.entities.single.keyword, 'tick');

        // Entering the next room hides this one straight away.
        n.processLine('Nice forest (n,e,s,w)');
        expect(container.read(roomInsightProvider), isNull);
        async.elapse(const Duration(seconds: 1));
        expect(container.read(roomInsightProvider)!.name, 'Nice forest');

        container.dispose();
      });
    });

    test('lines after the block ends do not join the room', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        final n = container.read(roomInsightProvider.notifier);
        for (final l in ['Light forest (n,e,s,w)', 'A raven.', '> ', '']) {
          n.processLine(l);
        }
        n.processLine('A goblin.');
        async.elapse(const Duration(seconds: 1));
        expect(container.read(roomInsightProvider)!.entities.length, 1);
        container.dispose();
      });
    });
  });
}
