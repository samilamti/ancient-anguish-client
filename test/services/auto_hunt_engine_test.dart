import 'dart:math';

import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/services/hunt/auto_hunt_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 11, 13, 12);
  DateTime at(int seconds) => t0.add(Duration(milliseconds: seconds * 1000));

  AutoHuntEngine engine({
    List<String> targets = const ['spider', 'tick'],
    List<String> avoid = const ['hill giant'],
    int seed = 1,
  }) =>
      AutoHuntEngine(
        targets: targets,
        avoid: avoid,
        stepDelay: const Duration(seconds: 6),
        random: Random(seed),
      );

  RoomSighting room(String header, [List<String> lines = const []]) =>
      RoomSighting(exits: RoomSighting.exitsOf(header)!, lines: lines);

  test('parses exits from a room header', () {
    expect(RoomSighting.exitsOf('Forest path (n,e,sw)'), ['n', 'e', 'sw']);
    expect(RoomSighting.exitsOf('You see nothing.'), isNull);
  });

  test('looks first when it has no room', () {
    final e = engine();
    expect(e.tick(now: at(0), inCombat: false), 'look');
    expect(e.tick(now: at(1), inCombat: false), isNull);
  });

  test('attacks a target after the arrival pause', () {
    final e = engine();
    e.onRoom(room('Dark cave (n,s)', ['A giant spider']), at(0));
    expect(e.tick(now: at(0), inCombat: false), isNull);
    expect(e.tick(now: at(1), inCombat: false), 'kill spider');
    // Waits for the fight to start rather than spamming.
    expect(e.tick(now: at(2), inCombat: false), isNull);
  });

  test('ignores a target only mentioned in description prose', () {
    final e = engine();
    e.onRoom(
        room('Dark cave (n)', [
          'Thick webs hang from the ceiling, spun by some spider long gone.',
        ]),
        at(0));
    expect(e.tick(now: at(1), inCombat: false), isNull);
    expect(e.tick(now: at(6), inCombat: false), 'n');
  });

  test('waits through combat, then looks again', () {
    final e = engine();
    e.onRoom(room('Dark cave (n,s)', ['A giant spider']), at(0));
    expect(e.tick(now: at(1), inCombat: false), 'kill spider');
    expect(e.tick(now: at(2), inCombat: true), isNull);
    expect(e.tick(now: at(10), inCombat: true), isNull);
    expect(e.tick(now: at(11), inCombat: false), isNull);
    expect(e.tick(now: at(13), inCombat: false), 'look');
  });

  test('gives up on a kill that never starts a fight', () {
    final e = engine();
    e.onRoom(room('Dark cave (n)', ['A giant spider']), at(0));
    expect(e.tick(now: at(1), inCombat: false), 'kill spider');
    expect(e.tick(now: at(6), inCombat: false), isNull);
    // Not retried; moves on once the step delay has passed.
    expect(e.tick(now: at(7), inCombat: false), 'n');
  });

  test('walks only n/s/e/w, never ne or up', () {
    final e = engine();
    e.onRoom(room('Crossroads (ne,u,w)'), at(0));
    expect(e.tick(now: at(6), inCombat: false), 'w');
  });

  test('does not walk straight back when another way exists', () {
    for (var seed = 0; seed < 20; seed++) {
      final e = engine(seed: seed);
      e.onRoom(room('A (e)'), at(0));
      expect(e.tick(now: at(6), inCombat: false), 'e');
      e.onRoom(room('B (e,w)'), at(7));
      expect(e.tick(now: at(13), inCombat: false), 'e');
    }
  });

  test('leaves a room holding something on the avoid list, back the way it came',
      () {
    final e = engine();
    e.onRoom(room('A (n)'), at(0));
    expect(e.tick(now: at(6), inCombat: false), 'n');
    e.onRoom(room('B (n,s,e)', ['A hill giant', 'A giant spider']), at(7));
    expect(e.status, contains('hill giant'));
    expect(e.tick(now: at(7), inCombat: false), 's');
  });

  test('avoid wins over a fight', () {
    final e = engine();
    e.onRoom(room('B (e)', ['A huge hill giant']), at(0));
    expect(e.tick(now: at(0), inCombat: true), 'e');
  });

  test('a blocked exit is dropped and another tried', () {
    final e = engine();
    e.onRoom(room('A (n,s)'), at(0));
    final first = e.tick(now: at(6), inCombat: false);
    expect(e.tick(now: at(10), inCombat: false), isNull);
    final second = e.tick(now: at(15), inCombat: false);
    expect(second, isNot(first));
    expect(['n', 's'], contains(second));
  });

  test('reports stuck when there is no n/s/e/w exit', () {
    final e = engine();
    e.onRoom(room('Pit (u)'), at(0));
    expect(e.tick(now: at(6), inCombat: false), isNull);
    expect(e.stuck, isTrue);
  });

  test('configure swaps lists without losing the room', () {
    final e = engine(targets: const ['tick']);
    e.onRoom(room('Cave (n)', ['A giant spider']), at(0));
    e.configure(
        targets: const ['spider'],
        avoid: const [],
        stepDelay: const Duration(seconds: 6));
    expect(e.tick(now: at(1), inCombat: false), 'kill spider');
  });

  test('settings: avoid defaults to hill giant, a cleared list stays cleared',
      () {
    expect(AppSettings.fromJson({}).autoHuntAvoid, ['hill giant']);
    final cleared = AppSettings.fromJson(
        AppSettings().copyWith(autoHuntAvoid: const [], autoHuntTargets: const ['tick']).toJson());
    expect(cleared.autoHuntAvoid, isEmpty);
    expect(cleared.autoHuntTargets, ['tick']);
    expect(cleared.autoHuntStepSeconds, 6);
  });

  group('RoomBlockReader', () {
    List<RoomSighting> readAll(List<String> lines) {
      final r = RoomBlockReader();
      return [
        for (final l in lines) ?r.feed(l),
      ];
    }

    const forestLook = [
      'You walk through the forest of pines in the valley in the mountains.',
      'Further to the north and the south you see the mountains rise high above you.',
      'The valley continues to the west. Close by to the north are some woods. There',
      'is a little sign on a tree. ',
      ' Obvious directions are:',
      '  north, east, west.',
      'A little spider.',
      '',
    ];

    test('reads spelled-out exits from look output', () {
      final rooms = readAll(forestLook);
      expect(rooms, hasLength(1));
      expect(rooms.single.exits, ['n', 'e', 'w']);
      expect(rooms.single.lines, ['A little spider.']);
    });

    test('the hunter attacks the spider from a look, then walks n/e/w', () {
      final e = engine();
      final room = readAll(forestLook).single;
      e.onRoom(room, at(0));
      expect(e.tick(now: at(1), inCombat: false), 'kill spider');
      final e2 = engine(targets: const ['tick']);
      e2.onRoom(room, at(0));
      expect(['n', 'e', 'w'], contains(e2.tick(now: at(6), inCombat: false)));
    });

    test('the description, which mentions north and woods, is not a sighting',
        () {
      final rooms = readAll(forestLook.take(4).toList());
      expect(rooms, isEmpty);
    });

    test('exits on the same line, one exit, and a list split over lines', () {
      expect(readAll(['Obvious directions are: north and southwest.', 'A tick', ''])
          .single.exits, ['n', 'sw']);
      expect(readAll(['There is one obvious exit: west.', '']).single.exits,
          ['w']);
      expect(readAll(['Obvious directions are:', '  north, south,', '  east.', '']).single.exits,
          ['n', 's', 'e']);
      expect(readAll(['There are no obvious exits.', '']).single.exits, isEmpty);
    });

    test('a short-exit header still works and ends at the prompt', () {
      final rooms = readAll(['Dark cave (n,s)', 'A giant spider', '<HP 10>']);
      expect(rooms.single.exits, ['n', 's']);
      expect(rooms.single.lines, ['A giant spider']);
    });

    test('a new room ends the previous one', () {
      final rooms = readAll(['A (n)', 'A tick', 'B (s)', 'A spider', '']);
      expect(rooms.map((r) => r.exits), [
        ['n'],
        ['s'],
      ]);
    });
  });
}
