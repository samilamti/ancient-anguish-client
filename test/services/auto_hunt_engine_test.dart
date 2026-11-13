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
}
