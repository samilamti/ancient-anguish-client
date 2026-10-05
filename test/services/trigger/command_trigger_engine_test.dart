import 'package:ancient_anguish_client/models/text_link_rule.dart';
import 'package:ancient_anguish_client/services/trigger/command_trigger_engine.dart';
import 'package:ancient_anguish_client/services/user_activity_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 5, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  const door = TextLinkRule(
    id: 'door',
    name: 'Open door',
    pattern: r'The (\w+) door is closed\.',
    commandTemplate: r'open $1 door',
  );

  group('CommandTriggerEngine', () {
    test('fires the resolved command once the player has been idle 3s', () {
      final engine = CommandTriggerEngine([door]);
      expect(
        engine.commandsFor('The oak door is closed.',
            now: at(3000), lastInteraction: t0),
        ['open oak door'],
      );
    });

    test('stays quiet while the player interacted under 3s ago', () {
      final engine = CommandTriggerEngine([door]);
      expect(
        engine.commandsFor('The oak door is closed.',
            now: at(2999), lastInteraction: t0),
        isEmpty,
      );
    });

    test('a rule fires at most once per cooldown window', () {
      final engine = CommandTriggerEngine([door]);
      const line = 'The oak door is closed.';
      expect(engine.commandsFor(line, now: at(5000), lastInteraction: t0),
          hasLength(1));
      expect(engine.commandsFor(line, now: at(5500), lastInteraction: t0),
          isEmpty);
      expect(engine.commandsFor(line, now: at(6000), lastInteraction: t0),
          hasLength(1));
    });

    test('a quiet window that was blocked does not start the cooldown', () {
      final engine = CommandTriggerEngine([door]);
      const line = 'The oak door is closed.';
      // Blocked by recent input...
      expect(engine.commandsFor(line, now: at(4000), lastInteraction: at(3000)),
          isEmpty);
      // ...so it is free to fire as soon as the player goes idle.
      expect(engine.commandsFor(line, now: at(6000), lastInteraction: at(3000)),
          ['open oak door']);
    });

    test('skips disabled rules, broken regexes and non-matching lines', () {
      final engine = CommandTriggerEngine([
        door.copyWith(id: 'off', enabled: false),
        const TextLinkRule(
            id: 'bad', name: 'bad', pattern: '(', commandTemplate: 'x'),
      ]);
      expect(engine.isEmpty, isTrue);
      expect(
        CommandTriggerEngine([door]).commandsFor('You are hungry.',
            now: at(9000), lastInteraction: t0),
        isEmpty,
      );
    });

    test('several matching rules fire in rule order', () {
      final engine = CommandTriggerEngine([
        door,
        const TextLinkRule(
            id: 'look', name: 'look', pattern: 'door', commandTemplate: 'look'),
      ]);
      expect(
        engine.commandsFor('The oak door is closed.',
            now: at(3000), lastInteraction: t0),
        ['open oak door', 'look'],
      );
    });
  });

  group('UserActivityTracker', () {
    test('creation counts as an interaction, and marking moves it', () {
      var now = t0;
      final tracker = UserActivityTracker(clock: () => now);
      expect(tracker.lastInteraction, t0);
      now = at(4000);
      tracker.markInteraction();
      expect(tracker.lastInteraction, at(4000));
    });
  });
}
