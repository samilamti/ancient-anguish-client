import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/battle_stats.dart';
import '../services/parser/battle_text_classifier.dart';
import 'battle_provider.dart';

/// Provides the running [BattleStats] for the fight in progress.
final battleStatsProvider =
    NotifierProvider<BattleStatsNotifier, BattleStats>(BattleStatsNotifier.new);

/// Accumulates classified combat lines into [BattleStats].
///
/// Deliberately keeps its own idle timer rather than listening to
/// [battleStateProvider]: the terminal buffer calls
/// `BattleNotifier.onBattlePatternDetected` and [record] back to back on the
/// same line, and Riverpod gives no ordering guarantee between a state change
/// and the listeners watching for it. Owning the timer makes "when does a
/// fight end" answerable without depending on notification order — and makes
/// the whole notifier testable under `fakeAsync` with no other providers.
class BattleStatsNotifier extends Notifier<BattleStats> {
  /// A fight ends after this long without combat output. Shared with
  /// [BattleNotifier] so the HUD and battle mode disappear together.
  static Duration get battleTimeout => BattleNotifier.battleTimeout;

  Timer? _idleTimer;

  @override
  BattleStats build() {
    ref.onDispose(() => _idleTimer?.cancel());
    return BattleStats.initial;
  }

  /// Folds one classified combat line into the tallies.
  ///
  /// The first line after a lull starts a fresh fight, so a night of grinding
  /// reads as per-fight numbers rather than one ever-growing total. A kill does
  /// *not* start one: pulling three mobs is one fight, and its [
  /// BattleStats.resolutions] counter is the interesting part of it.
  void record(BattleLineMatch match, {String? rawLine, DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    var next = state.active ? state : _freshBattle(timestamp);

    next = switch (match.kind) {
      BattleLineKind.yourHit => next.copyWith(hitsDealt: next.hitsDealt + 1),
      BattleLineKind.yourMiss =>
        next.copyWith(missesDealt: next.missesDealt + 1),
      BattleLineKind.incomingHit =>
        next.copyWith(hitsTaken: next.hitsTaken + 1),
      BattleLineKind.incomingMiss =>
        next.copyWith(missesAgainst: next.missesAgainst + 1),
      BattleLineKind.otherHit => next.copyWith(otherHits: next.otherHits + 1),
      BattleLineKind.otherMiss =>
        next.copyWith(otherMisses: next.otherMisses + 1),
      BattleLineKind.resolution =>
        next.copyWith(resolutions: next.resolutions + 1),
      // Chatter keeps the fight alive (it resets the idle timer below and shows
      // as the latest line) but scores nothing — see [BattleLineKind.flavour].
      BattleLineKind.flavour => next,
      BattleLineKind.vitals => next.copyWith(
          rounds: next.rounds + 1,
          // `hpStart` is only ever set once per fight — copyWith's null-means-
          // keep semantics would silently ignore a later write anyway, but the
          // explicit guard documents that the baseline is the *first* reading.
          hpStart: next.hpStart ?? match.hp,
          hpNow: match.hp,
          spNow: match.sp,
        ),
    };

    state = next.copyWith(
      target: match.opponent ?? next.target,
      latestLine: rawLine ?? next.latestLine,
    );

    _idleTimer?.cancel();
    _idleTimer = Timer(battleTimeout, _onIdle);
  }

  BattleStats _freshBattle(DateTime timestamp) =>
      BattleStats(active: true, startedAt: timestamp);

  /// Combat has gone quiet — freeze the tallies but keep them readable so a
  /// glance right after the kill still shows how the fight went.
  void _onIdle() {
    _idleTimer = null;
    if (state.active) state = state.copyWith(active: false);
  }

  /// Clears everything (e.g. on disconnect).
  void reset() {
    _idleTimer?.cancel();
    _idleTimer = null;
    state = BattleStats.initial;
  }
}
