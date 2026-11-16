import 'package:ancient_anguish_client/services/kata/kata_engine.dart';
import 'package:ancient_anguish_client/services/parser/battle_text_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fires one slot per call and loops after the last action', () {
    final e = KataEngine(['kick', 'punch', 'cast heal', '', '', '', '', '', '', '']);
    expect(e.length, 3);
    expect([for (var i = 0; i < 7; i++) e.next()],
        ['kick', 'punch', 'cast heal', 'kick', 'punch', 'cast heal', 'kick']);
  });

  test('empty slots inside the Kata are idle seconds', () {
    final e = KataEngine(['kick', '', 'punch', '', '', '', '', '', '', '']);
    expect([for (var i = 0; i < 4; i++) e.next()], ['kick', null, 'punch', 'kick']);
  });

  test('a leading empty slot waits a second', () {
    final e = KataEngine(['', 'kick']);
    expect([e.next(), e.next(), e.next()], [null, 'kick', null]);
  });

  test('all empty is empty and never fires', () {
    final e = KataEngine(List.filled(10, '  '));
    expect(e.isEmpty, isTrue);
    expect(e.next(), isNull);
  });

  test('nextSlot and reset', () {
    final e = KataEngine(['a', 'b']);
    expect(e.nextSlot, 1);
    e.next();
    expect(e.nextSlot, 2);
    e.reset();
    expect(e.nextSlot, 1);
    expect(e.next(), 'a');
  });

  test('only your own blows start a fight', () {
    expect(KataEngine.startsFight(BattleLineKind.yourHit), isTrue);
    expect(KataEngine.startsFight(BattleLineKind.incomingMiss), isTrue);
    expect(KataEngine.startsFight(BattleLineKind.otherHit), isFalse);
    expect(KataEngine.startsFight(BattleLineKind.vitals), isFalse);
    expect(KataEngine.startsFight(BattleLineKind.resolution), isFalse);
  });
}
