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
  const doorLine = 'The oak door is closed.';

  /// Matches at [matchMs], then takes the pending command one fire delay
  /// later, with no interaction since [t0].
  String? fireAt(CommandTriggerEngine engine, int matchMs,
      {String line = doorLine}) {
    if (engine.onLine(line, now: at(matchMs), lastInteraction: t0) == null) {
      return null;
    }
    return engine.takePending(now: at(matchMs + 1000), lastInteraction: t0);
  }

  group('CommandTriggerEngine', () {
    test('delays are the requested ones', () {
      expect(CommandTriggerEngine.idleThreshold, const Duration(seconds: 3));
      expect(CommandTriggerEngine.fireDelay, const Duration(seconds: 1));
      expect(CommandTriggerEngine.cooldown, const Duration(seconds: 3));
    });

    test('a match after 3s idle becomes pending, then fires', () {
      final engine = CommandTriggerEngine([door]);
      expect(engine.onLine(doorLine, now: at(3000), lastInteraction: t0),
          'open oak door');
      expect(engine.hasPending, isTrue);
      expect(engine.takePending(now: at(4000), lastInteraction: t0),
          'open oak door');
      expect(engine.hasPending, isFalse);
    });

    test('no match while the player interacted under 3s ago', () {
      final engine = CommandTriggerEngine([door]);
      expect(engine.onLine(doorLine, now: at(2999), lastInteraction: t0),
          isNull);
    });

    test('interaction during the fire delay cancels the trigger', () {
      final engine = CommandTriggerEngine([door]);
      engine.onLine(doorLine, now: at(3000), lastInteraction: t0);
      expect(engine.takePending(now: at(4000), lastInteraction: at(3500)),
          isNull);
      // A cancelled trigger starts no cooldown and frees the pending slot.
      expect(engine.hasPending, isFalse);
      expect(
          engine.onLine(doorLine, now: at(6500), lastInteraction: at(3500)),
          'open oak door');
    });

    test('only one trigger is pending at a time', () {
      final engine = CommandTriggerEngine([door]);
      expect(engine.onLine(doorLine, now: at(3000), lastInteraction: t0),
          isNotNull);
      expect(engine.onLine(doorLine, now: at(3100), lastInteraction: t0),
          isNull);
    });

    test('after a firing, no trigger fires for 3 seconds', () {
      final other = door.copyWith(
          id: 'hungry', pattern: 'You are hungry', commandTemplate: 'eat');
      final engine = CommandTriggerEngine([door, other]);
      expect(fireAt(engine, 3000), 'open oak door'); // fired at 4000
      expect(fireAt(engine, 6999, line: 'You are hungry.'), isNull);
      expect(fireAt(engine, 7000, line: 'You are hungry.'), 'eat');
    });

    test('cancelPending frees the slot without firing', () {
      final engine = CommandTriggerEngine([door]);
      engine.onLine(doorLine, now: at(3000), lastInteraction: t0);
      engine.cancelPending();
      expect(engine.takePending(now: at(4000), lastInteraction: t0), isNull);
      expect(engine.onLine(doorLine, now: at(4000), lastInteraction: t0),
          isNotNull);
    });

    test('skips disabled rules, broken regexes and non-matching lines', () {
      final engine = CommandTriggerEngine([
        door.copyWith(id: 'off', enabled: false),
        const TextLinkRule(
            id: 'bad', name: 'bad', pattern: '(', commandTemplate: 'x'),
      ]);
      expect(engine.isEmpty, isTrue);
      expect(
        CommandTriggerEngine([door]).onLine('You are hungry.',
            now: at(9000), lastInteraction: t0),
        isNull,
      );
    });

    test('the first matching rule wins', () {
      final engine = CommandTriggerEngine([
        door,
        const TextLinkRule(
            id: 'look', name: 'look', pattern: 'door', commandTemplate: 'look'),
      ]);
      expect(fireAt(engine, 3000), 'open oak door');
    });
  });

  group('CommandTriggerEngine.matchNow (instant mode)', () {
    test('matches with no idle gate, delay or cooldown', () {
      final engine = CommandTriggerEngine([door]);
      expect(engine.matchNow(doorLine, now: t0), 'open oak door');
      expect(engine.matchNow('You are hungry.', now: at(10)), isNull);
      expect(engine.matchNow(doorLine, now: at(20)), 'open oak door');
    });

    test('leaves the delayed path\'s state alone', () {
      final engine = CommandTriggerEngine([door]);
      engine.matchNow(doorLine, now: t0);
      expect(engine.hasPending, isFalse);
      // No cooldown was started either.
      expect(engine.onLine(doorLine, now: at(3000), lastInteraction: t0),
          'open oak door');
    });
  });

  group('CommandTriggerEngine.matchNow rate limit', () {
    test('limit is 2 per rolling second', () {
      expect(CommandTriggerEngine.instantRateLimit, 2);
      expect(CommandTriggerEngine.instantRateWindow,
          const Duration(seconds: 1));
    });

    test('drops matches over the limit, across all rules', () {
      final hungry = door.copyWith(
          id: 'hungry', pattern: 'You are hungry', commandTemplate: 'eat');
      final engine = CommandTriggerEngine([door, hungry]);
      expect(engine.matchNow(doorLine, now: t0), isNotNull);
      expect(engine.matchNow('You are hungry.', now: at(100)), 'eat');
      expect(engine.matchNow(doorLine, now: at(200)), isNull);
      expect(engine.matchNow('You are hungry.', now: at(999)), isNull);
    });

    test('the window rolls: a slot frees one second after each firing', () {
      final engine = CommandTriggerEngine([door]);
      engine.matchNow(doorLine, now: t0);
      engine.matchNow(doorLine, now: at(600));
      expect(engine.matchNow(doorLine, now: at(999)), isNull);
      expect(engine.matchNow(doorLine, now: at(1000)), isNotNull);
      // at(600) and at(1000) are both inside the window ending at 1500.
      expect(engine.matchNow(doorLine, now: at(1500)), isNull);
      expect(engine.matchNow(doorLine, now: at(1600)), isNotNull);
    });

    test('dropped and non-matching lines use up no slots', () {
      final engine = CommandTriggerEngine([door]);
      for (var i = 0; i < 5; i++) {
        engine.matchNow('You are hungry.', now: at(i));
      }
      expect(engine.matchNow(doorLine, now: at(10)), isNotNull);
      expect(engine.matchNow(doorLine, now: at(20)), isNotNull);
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
