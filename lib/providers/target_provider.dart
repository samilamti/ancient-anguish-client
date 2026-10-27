import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/parser/battle_text_classifier.dart';
import 'battle_provider.dart';
import 'room_targets_provider.dart';
import 'settings_provider.dart';

/// The creature `$target` names: a single keyword as Ancient Anguish accepts
/// it after `kill`, with the ordinal when the room holds several (`orc`,
/// `orc 2`). `null` when nothing is targeted.
///
/// It only *names* a creature. Nothing here sends a command or chooses to
/// attack anything; see design/keyboard-play-mode.md, "Fair play".
final targetProvider =
    NotifierProvider<TargetNotifier, String?>(TargetNotifier.new);

/// The keyword without AA's ordinal: `orc 2` → `orc`. This is the unit the
/// ignore list and death lines work in, since neither can tell orcs apart.
String targetBaseKeyword(String target) =>
    target.replaceFirst(RegExp(r'\s+\d+$'), '');

/// Reduces a combat display name to the keyword a kill link would use:
/// lower-cased, last word, punctuation stripped (`Ship rat` → `rat`).
/// Returns `null` when nothing usable is left.
String? targetKeywordFromName(String name) {
  final words = name
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r"[^a-z\-']"), ''))
      .where((w) => w.isNotEmpty)
      .toList();
  return words.isEmpty ? null : words.last;
}

class TargetNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Entering a room that doesn't hold the target drops it, but never during
    // a fight: a creature that fled is still the one you're chasing.
    ref.listen<List<String>>(roomTargetInstancesProvider, (_, instances) {
      onRoomTargets(instances,
          inBattle: ref.read(battleStateProvider).inBattle);
    });
    return null;
  }

  Set<String> get _ignored =>
      ref.read(settingsProvider).ignoredKillTargets.toSet();

  /// The Tab cycle: every creature instance in the room, minus ignored ones.
  List<String> get candidates => [
        for (final t in ref.read(roomTargetInstancesProvider))
          if (!_ignored.contains(targetBaseKeyword(t))) t,
      ];

  /// Sets the target from a kill-link click or the Kill picker.
  void set(String target) {
    final normalized = AppSettings.normalizeTarget(target);
    state = normalized.isEmpty ? null : normalized;
  }

  void clear() => state = null;

  /// Tab: the next candidate after the current target, wrapping round. With
  /// no target (or one no longer in the cycle) it starts at the first.
  void next() => _step(1);

  /// Shift+Tab: the previous candidate, wrapping round.
  void previous() => _step(-1);

  void _step(int delta) {
    final list = candidates;
    if (list.isEmpty) {
      state = null;
      return;
    }
    final i = state == null ? -1 : list.indexOf(state!);
    if (i < 0) {
      state = delta > 0 ? list.first : list.last;
      return;
    }
    state = list[(i + delta) % list.length];
  }

  /// X in play mode: puts the current target's keyword on the ignore list and
  /// moves on to the next candidate. Returns the keyword that was ignored, so
  /// the caller can offer Undo, or `null` when nothing was targeted.
  String? ignoreCurrent() {
    final current = state;
    if (current == null) return null;
    final keyword = targetBaseKeyword(current);
    final before = candidates;
    final at = before.indexOf(current);
    ref.read(settingsProvider.notifier).addIgnoredKillTarget(keyword);
    final after = candidates;
    if (after.isEmpty) {
      state = null;
      return keyword;
    }
    // The first remaining candidate that came after the ignored one, so X
    // walks forward through the room the way Tab does.
    final following = at < 0
        ? const <String>[]
        : before.skip(at + 1).where(after.contains).toList();
    state = following.isNotEmpty ? following.first : after.first;
    return keyword;
  }

  /// Feeds one classified combat line. A death naming the target's keyword
  /// clears it (with duplicates the line can't say which one died, and AA
  /// renumbers the rest, so any death of that keyword clears). Any other
  /// exchange with no target set adopts the opponent of record.
  void onBattleLine(BattleLineMatch match) {
    final keyword =
        match.opponent == null ? null : targetKeywordFromName(match.opponent!);
    if (match.kind == BattleLineKind.resolution) {
      if (state != null && keyword == targetBaseKeyword(state!)) state = null;
      return;
    }
    if (state != null || keyword == null) return;
    if (_ignored.contains(keyword)) return;
    state = keyword;
  }

  /// Called with the room's creature instances whenever a new room block
  /// commits.
  void onRoomTargets(List<String> instances, {required bool inBattle}) {
    final current = state;
    if (current == null || inBattle) return;
    if (!instances.contains(current)) state = null;
  }
}
