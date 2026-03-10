import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/game_state.dart';

void main() {
  group('GameState - default constructor', () {
    test('initial has all zeros and nulls', () {
      const gs = GameState();
      expect(gs.hp, 0);
      expect(gs.maxHp, 0);
      expect(gs.sp, 0);
      expect(gs.maxSp, 0);
      expect(gs.x, isNull);
      expect(gs.y, isNull);
      expect(gs.playerName, isNull);
      expect(gs.playerClass, isNull);
      expect(gs.coins, isNull);
      expect(gs.xp, isNull);
      expect(gs.currentArea, isNull);
    });

    test('initial constant matches default constructor', () {
      const gs = GameState();
      expect(GameState.initial.hp, gs.hp);
      expect(GameState.initial.maxHp, gs.maxHp);
      expect(GameState.initial.sp, gs.sp);
      expect(GameState.initial.maxSp, gs.maxSp);
      expect(GameState.initial.x, gs.x);
      expect(GameState.initial.y, gs.y);
      expect(GameState.initial.playerName, gs.playerName);
      expect(GameState.initial.currentArea, gs.currentArea);
    });
  });

  group('GameState - copyWith', () {
    test('copies all fields when specified', () {
      const gs = GameState();
      final copied = gs.copyWith(
        hp: 100,
        maxHp: 150,
        sp: 80,
        maxSp: 120,
        x: 5,
        y: -3,
        playerName: 'Gandalf',
        playerClass: 'mage',
        coins: 500,
        xp: 10000,
        currentArea: 'Tantallon',
      );

      expect(copied.hp, 100);
      expect(copied.maxHp, 150);
      expect(copied.sp, 80);
      expect(copied.maxSp, 120);
      expect(copied.x, 5);
      expect(copied.y, -3);
      expect(copied.playerName, 'Gandalf');
      expect(copied.playerClass, 'mage');
      expect(copied.coins, 500);
      expect(copied.xp, 10000);
      expect(copied.currentArea, 'Tantallon');
    });

    test('preserves fields not specified', () {
      final gs = const GameState().copyWith(
        hp: 50,
        maxHp: 100,
        x: 3,
        y: 4,
        playerName: 'Test',
        currentArea: 'Forest',
      );

      // Only update HP, leave everything else.
      final updated = gs.copyWith(hp: 75);
      expect(updated.hp, 75);
      expect(updated.maxHp, 100);
      expect(updated.sp, 0);
      expect(updated.x, 3);
      expect(updated.y, 4);
      expect(updated.playerName, 'Test');
      expect(updated.currentArea, 'Forest');
    });

    test('cannot clear nullable fields to null via copyWith (known limitation)',
        () {
      // Once x, y, currentArea are set, copyWith uses ?? so passing null
      // would just keep the old value. This documents the limitation.
      final gs = const GameState().copyWith(
        x: 5,
        y: 10,
        currentArea: 'Town',
      );

      // Attempting to "clear" by passing null keeps old value.
      final cleared = gs.copyWith(x: null, y: null, currentArea: null);
      expect(cleared.x, 5); // Not null — limitation.
      expect(cleared.y, 10);
      expect(cleared.currentArea, 'Town');
    });
  });

  group('GameState - hpFraction', () {
    test('returns 0.0 when maxHp is 0', () {
      const gs = GameState(hp: 0, maxHp: 0);
      expect(gs.hpFraction, 0.0);
    });

    test('returns 0.0 when both hp and maxHp are default 0', () {
      expect(const GameState().hpFraction, 0.0);
    });

    test('returns 0.5 for half HP', () {
      const gs = GameState(hp: 50, maxHp: 100);
      expect(gs.hpFraction, 0.5);
    });

    test('returns 1.0 for full HP', () {
      const gs = GameState(hp: 150, maxHp: 150);
      expect(gs.hpFraction, 1.0);
    });

    test('clamps to 1.0 if hp exceeds maxHp', () {
      const gs = GameState(hp: 200, maxHp: 100);
      expect(gs.hpFraction, 1.0);
    });

    test('handles hp of 0 with positive maxHp', () {
      const gs = GameState(hp: 0, maxHp: 100);
      expect(gs.hpFraction, 0.0);
    });
  });

  group('GameState - spFraction', () {
    test('returns 0.0 when maxSp is 0', () {
      const gs = GameState(sp: 0, maxSp: 0);
      expect(gs.spFraction, 0.0);
    });

    test('returns correct fraction for partial SP', () {
      const gs = GameState(sp: 75, maxSp: 100);
      expect(gs.spFraction, 0.75);
    });

    test('clamps to 1.0 if sp exceeds maxSp', () {
      const gs = GameState(sp: 200, maxSp: 100);
      expect(gs.spFraction, 1.0);
    });
  });

  group('GameState - hasVitals', () {
    test('false when maxHp is 0', () {
      expect(const GameState().hasVitals, isFalse);
    });

    test('true when maxHp > 0', () {
      const gs = GameState(maxHp: 100);
      expect(gs.hasVitals, isTrue);
    });
  });

  group('GameState - hasCoordinates', () {
    test('false when both x and y are null', () {
      expect(const GameState().hasCoordinates, isFalse);
    });

    test('false when only x is set', () {
      final gs = const GameState().copyWith(x: 5);
      expect(gs.hasCoordinates, isFalse);
    });

    test('false when only y is set', () {
      final gs = const GameState().copyWith(y: 10);
      expect(gs.hasCoordinates, isFalse);
    });

    test('true when both x and y are set', () {
      final gs = const GameState().copyWith(x: 3, y: 7);
      expect(gs.hasCoordinates, isTrue);
    });

    test('true with negative coordinates', () {
      final gs = const GameState().copyWith(x: -5, y: -10);
      expect(gs.hasCoordinates, isTrue);
    });

    test('true with zero coordinates', () {
      final gs = const GameState().copyWith(x: 0, y: 0);
      expect(gs.hasCoordinates, isTrue);
    });
  });
}
