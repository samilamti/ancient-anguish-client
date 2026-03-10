import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/connection_provider.dart';

void main() {
  late ProviderContainer container;
  late CommandHistoryNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(commandHistoryProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('CommandHistoryNotifier - add', () {
    test('adds command to front of list', () {
      notifier.add('first');
      notifier.add('second');
      final state = container.read(commandHistoryProvider);
      expect(state.first, 'second');
      expect(state.last, 'first');
    });

    test('ignores empty and whitespace-only commands', () {
      notifier.add('');
      notifier.add('   ');
      notifier.add('\t');
      expect(container.read(commandHistoryProvider), isEmpty);
    });

    test('deduplicates consecutive identical commands', () {
      notifier.add('look');
      notifier.add('look');
      notifier.add('look');
      expect(container.read(commandHistoryProvider), hasLength(1));
    });

    test('allows non-consecutive duplicates', () {
      notifier.add('look');
      notifier.add('north');
      notifier.add('look');
      expect(container.read(commandHistoryProvider), hasLength(3));
    });

    test('caps history at 500 entries', () {
      for (var i = 0; i < 510; i++) {
        notifier.add('command_$i');
      }
      expect(container.read(commandHistoryProvider), hasLength(500));
      // Most recent should be first.
      expect(container.read(commandHistoryProvider).first, 'command_509');
    });
  });

  group('CommandHistoryNotifier - previous', () {
    test('returns null when history is empty', () {
      expect(notifier.previous(), isNull);
    });

    test('returns most recent command on first call', () {
      notifier.add('first');
      notifier.add('second');
      expect(notifier.previous(), 'second');
    });

    test('returns progressively older commands on repeated calls', () {
      notifier.add('first');
      notifier.add('second');
      notifier.add('third');

      expect(notifier.previous(), 'third');
      expect(notifier.previous(), 'second');
      expect(notifier.previous(), 'first');
    });

    test('stops at oldest command and keeps returning it', () {
      notifier.add('only');
      expect(notifier.previous(), 'only');
      expect(notifier.previous(), 'only');
      expect(notifier.previous(), 'only');
    });
  });

  group('CommandHistoryNotifier - next', () {
    test('returns empty string when at position -1', () {
      notifier.add('first');
      // Without calling previous(), position is -1.
      expect(notifier.next(), '');
    });

    test('returns newer command after calling previous', () {
      notifier.add('first');
      notifier.add('second');
      notifier.add('third');

      // Go back two steps.
      notifier.previous(); // third
      notifier.previous(); // second

      // Go forward.
      expect(notifier.next(), 'third');
    });

    test('returns empty string when navigating past newest', () {
      notifier.add('first');
      notifier.add('second');

      notifier.previous(); // second
      notifier.next(); // back to "newest" (position 0)
      expect(notifier.next(), ''); // past newest
    });
  });

  group('CommandHistoryNotifier - resetPosition', () {
    test('resets so previous starts from newest again', () {
      notifier.add('first');
      notifier.add('second');

      notifier.previous(); // second
      notifier.previous(); // first

      notifier.resetPosition();

      expect(notifier.previous(), 'second'); // starts from newest
    });
  });

  group('CommandHistoryNotifier - interaction', () {
    test('add resets position to -1', () {
      notifier.add('first');
      notifier.add('second');

      notifier.previous(); // second
      notifier.previous(); // first

      notifier.add('third');

      // Position should be reset, so previous returns newest.
      expect(notifier.previous(), 'third');
    });

    test('full up-down navigation cycle works correctly', () {
      notifier.add('alpha');
      notifier.add('beta');
      notifier.add('gamma');

      // Navigate all the way back.
      expect(notifier.previous(), 'gamma');
      expect(notifier.previous(), 'beta');
      expect(notifier.previous(), 'alpha');

      // Navigate all the way forward.
      expect(notifier.next(), 'beta');
      expect(notifier.next(), 'gamma');
      expect(notifier.next(), ''); // Past newest.
    });
  });
}
