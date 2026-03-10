import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/battle_provider.dart';

void main() {
  group('BattleNotifier.parseBattleLine', () {
    test('matches standard battle pattern', () {
      final result = BattleNotifier.parseBattleLine('HP: 136  SP: 149');
      expect(result, isNotNull);
      expect(result!.hp, 136);
      expect(result.sp, 149);
    });

    test('matches with extra spaces', () {
      final result = BattleNotifier.parseBattleLine('HP:  42  SP:   7');
      expect(result, isNotNull);
      expect(result!.hp, 42);
      expect(result.sp, 7);
    });

    test('matches with single space', () {
      final result = BattleNotifier.parseBattleLine('HP: 200 SP: 100');
      expect(result, isNotNull);
      expect(result!.hp, 200);
      expect(result.sp, 100);
    });

    test('matches pattern embedded in longer line', () {
      final result = BattleNotifier.parseBattleLine(
        'You attack the orc. HP: 90  SP: 50',
      );
      expect(result, isNotNull);
      expect(result!.hp, 90);
      expect(result.sp, 50);
    });

    test('returns null for unrelated lines', () {
      expect(BattleNotifier.parseBattleLine('You see a forest.'), isNull);
      expect(BattleNotifier.parseBattleLine('HP is low'), isNull);
      expect(BattleNotifier.parseBattleLine('SP: 100'), isNull);
    });
  });

  group('BattleNotifier.isBattleIndicator', () {
    test('matches "You missed" at start of line', () {
      expect(
        BattleNotifier.isBattleIndicator('You missed the orc.'),
        isTrue,
      );
    });

    test('matches "missed you." at end of line', () {
      expect(
        BattleNotifier.isBattleIndicator('The orc missed you.'),
        isTrue,
      );
    });

    test('does not match "missed" in unrelated context', () {
      expect(
        BattleNotifier.isBattleIndicator('You missed the bus yesterday.'),
        isTrue, // still matches "^You missed "
      );
    });

    test('does not match partial patterns', () {
      expect(
        BattleNotifier.isBattleIndicator('He missed the target.'),
        isFalse,
      );
      expect(
        BattleNotifier.isBattleIndicator('I missed you so much'),
        isFalse, // no period at end
      );
    });

    test('returns false for unrelated lines', () {
      expect(BattleNotifier.isBattleIndicator('You see a forest.'), isFalse);
      expect(BattleNotifier.isBattleIndicator('HP: 100  SP: 50'), isFalse);
    });
  });

  group('BattleNotifier - state management', () {
    late ProviderContainer container;
    late BattleNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(battleStateProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('starts with inBattle = false', () {
      final state = container.read(battleStateProvider);
      expect(state.inBattle, isFalse);
    });

    test('onBattlePatternDetected sets inBattle to true', () {
      notifier.onBattlePatternDetected();
      expect(container.read(battleStateProvider).inBattle, isTrue);
    });

    test('battle ends after 5 second timeout', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(battleStateProvider.notifier);

        notifier.onBattlePatternDetected();
        expect(container.read(battleStateProvider).inBattle, isTrue);

        async.elapse(const Duration(seconds: 4));
        expect(container.read(battleStateProvider).inBattle, isTrue);

        async.elapse(const Duration(seconds: 1));
        expect(container.read(battleStateProvider).inBattle, isFalse);
      });
    });

    test('repeated patterns reset the timer', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(battleStateProvider.notifier);

        notifier.onBattlePatternDetected();
        async.elapse(const Duration(seconds: 3));
        expect(container.read(battleStateProvider).inBattle, isTrue);

        // Reset timer by detecting another pattern.
        notifier.onBattlePatternDetected();
        async.elapse(const Duration(seconds: 3));
        // Only 3s since last pattern — still in battle.
        expect(container.read(battleStateProvider).inBattle, isTrue);

        async.elapse(const Duration(seconds: 2));
        // 5s since last pattern — battle ends.
        expect(container.read(battleStateProvider).inBattle, isFalse);
      });
    });

    test('reset cancels timer and clears state', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(battleStateProvider.notifier);

        notifier.onBattlePatternDetected();
        expect(container.read(battleStateProvider).inBattle, isTrue);

        notifier.reset();
        expect(container.read(battleStateProvider).inBattle, isFalse);

        // Timer should be cancelled — no state change after 5s.
        async.elapse(const Duration(seconds: 6));
        expect(container.read(battleStateProvider).inBattle, isFalse);
      });
    });
  });
}
