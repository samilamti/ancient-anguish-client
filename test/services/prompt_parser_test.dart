import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';

void main() {
  late PromptParser parser;

  setUp(() {
    parser = PromptParser();
  });

  group('PromptParser - Basic Prompt', () {
    test('parses standard AA prompt "HP/MaxHP:SP/MaxSP>"', () {
      final state = parser.parseLine('125/125:80/80>');
      expect(state, isNotNull);
      expect(state!.hp, 125);
      expect(state.maxHp, 125);
      expect(state.sp, 80);
      expect(state.maxSp, 80);
    });

    test('parses prompt with reduced HP', () {
      final state = parser.parseLine('50/125:30/80>');
      expect(state, isNotNull);
      expect(state!.hp, 50);
      expect(state.maxHp, 125);
      expect(state.sp, 30);
      expect(state.maxSp, 80);
    });

    test('parses prompt embedded in other text', () {
      final state = parser.parseLine('Some text 100/200:50/100> more text');
      expect(state, isNotNull);
      expect(state!.hp, 100);
      expect(state.maxHp, 200);
    });

    test('returns null for non-prompt lines', () {
      expect(parser.parseLine('You enter a dark room.'), isNull);
      expect(parser.parseLine(''), isNull);
      expect(parser.parseLine('A goblin attacks you!'), isNull);
    });

    test('hpFraction and spFraction are correct', () {
      final state = parser.parseLine('50/100:25/50>');
      expect(state, isNotNull);
      expect(state!.hpFraction, 0.5);
      expect(state.spFraction, 0.5);
    });
  });

  group('PromptParser - CLIENT line', () {
    test('parses full CLIENT line', () {
      final state = parser.parseLine(
        'CLIENT:X:5:Y:12:Gandalf:fighter:1500:25000',
      );
      expect(state, isNotNull);
      expect(state!.x, 5);
      expect(state.y, 12);
      expect(state.playerName, 'Gandalf');
      expect(state.playerClass, 'fighter');
      expect(state.coins, 1500);
      expect(state.xp, 25000);
    });

    test('parses negative coordinates', () {
      final state = parser.parseLine(
        'CLIENT:X:-3:Y:-7:Frodo:thief:200:5000',
      );
      expect(state, isNotNull);
      expect(state!.x, -3);
      expect(state.y, -7);
    });

    test('preserves HP/SP from previous basic prompt', () {
      // First parse a basic prompt to set HP/SP.
      parser.parseLine('100/200:50/100>');

      // Then parse a CLIENT line (which doesn't contain HP/SP).
      final state = parser.parseLine(
        'CLIENT:X:0:Y:0:Test:mage:0:0',
      );
      expect(state, isNotNull);
      expect(state!.hp, 100);
      expect(state.maxHp, 200);
      expect(state.x, 0);
      expect(state.y, 0);
    });
  });

  group('PromptParser - State management', () {
    test('lastState returns most recent parse result', () {
      parser.parseLine('100/200:50/100>');
      expect(parser.lastState.hp, 100);

      parser.parseLine('90/200:45/100>');
      expect(parser.lastState.hp, 90);
    });

    test('non-prompt lines do not change lastState', () {
      parser.parseLine('100/200:50/100>');
      parser.parseLine('A room description that is not a prompt.');
      expect(parser.lastState.hp, 100);
    });

    test('reset clears state', () {
      parser.parseLine('100/200:50/100>');
      parser.reset();
      expect(parser.lastState.hp, 0);
      expect(parser.lastState.hasVitals, false);
    });
  });

  group('PromptParser - Custom patterns', () {
    test('uses custom regex when set', () {
      // Custom pattern: "HP:100/200 SP:50/100"
      parser.setCustomPattern(r'HP:(\d+)/(\d+) SP:(\d+)/(\d+)');

      final state = parser.parseLine('HP:75/150 SP:40/80');
      expect(state, isNotNull);
      expect(state!.hp, 75);
      expect(state.maxHp, 150);
      expect(state.sp, 40);
      expect(state.maxSp, 80);
    });

    test('invalid regex falls back gracefully', () {
      parser.setCustomPattern('[invalid');
      // Should still work with built-in patterns.
      final state = parser.parseLine('100/200:50/100>');
      expect(state, isNotNull);
    });

    test('null pattern reverts to defaults', () {
      parser.setCustomPattern(r'HP:(\d+)/(\d+) SP:(\d+)/(\d+)');
      parser.setCustomPattern(null);
      // Default pattern should work.
      final state = parser.parseLine('100/200:50/100>');
      expect(state, isNotNull);
    });

    test('empty string pattern reverts to defaults', () {
      parser.setCustomPattern(r'HP:(\d+)/(\d+) SP:(\d+)/(\d+)');
      parser.setCustomPattern('');
      // Default pattern should work after clearing custom pattern.
      final state = parser.parseLine('100/200:50/100>');
      expect(state, isNotNull);
    });

    test('custom pattern with fewer than 4 groups returns null', () {
      // Only 2 capture groups — parseLine should return null.
      parser.setCustomPattern(r'HP:(\d+)/(\d+)');
      final state = parser.parseLine('HP:100/200');
      expect(state, isNull);
    });

    test('custom pattern with non-numeric groups returns null', () {
      // Groups match but int.parse will fail.
      parser.setCustomPattern(r'(\w+)/(\w+):(\w+)/(\w+)>');
      final state = parser.parseLine('abc/def:ghi/jkl>');
      expect(state, isNull);
    });
  });
}
