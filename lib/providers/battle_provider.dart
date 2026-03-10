import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/battle_state.dart';

/// Provides the current [BattleState].
final battleStateProvider =
    NotifierProvider<BattleNotifier, BattleState>(BattleNotifier.new);

/// Manages combat detection via the `HP: <n>  SP: <n>` pattern the MUD sends
/// during battle rounds.
///
/// When the pattern arrives, [onBattlePatternDetected] sets `inBattle = true`
/// and starts (or resets) a 5-second timer. If no new pattern arrives before
/// the timer fires, battle mode ends.
class BattleNotifier extends Notifier<BattleState> {
  static final RegExp battleLineRegex = RegExp(r'HP:\s+(\d+)\s+SP:\s+(\d+)');

  /// How long to wait after the last battle pattern before ending battle mode.
  static const Duration battleTimeout = Duration(seconds: 5);

  Timer? _timer;

  @override
  BattleState build() {
    ref.onDispose(() => _timer?.cancel());
    return BattleState.initial;
  }

  /// Checks [plainText] for the battle pattern. Returns `({int hp, int sp})`
  /// if found, or `null` otherwise.
  static ({int hp, int sp})? parseBattleLine(String plainText) {
    final match = battleLineRegex.firstMatch(plainText);
    if (match == null) return null;
    return (hp: int.parse(match.group(1)!), sp: int.parse(match.group(2)!));
  }

  /// Called when a battle pattern line is detected in MUD output.
  void onBattlePatternDetected() {
    _timer?.cancel();
    _timer = Timer(battleTimeout, _onBattleTimeout);
    if (!state.inBattle) {
      state = state.copyWith(inBattle: true);
    }
  }

  void _onBattleTimeout() {
    state = state.copyWith(inBattle: false);
  }

  /// Resets battle state (e.g. on disconnect).
  void reset() {
    _timer?.cancel();
    _timer = null;
    state = BattleState.initial;
  }
}
