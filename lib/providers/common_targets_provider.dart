import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recent_words_provider.dart';
import 'room_targets_provider.dart';

/// Common MUD targets shown in the Kill picker. The list is static so the
/// player always sees the same recognisable creatures, regardless of what's
/// in the current room.
const List<String> kCommonTargets = [
  'bird',
  'insect',
  'orc',
  'troll',
  'giant',
  'goblin',
  'undead',
  'cow',
  'goat',
  'pig',
  'deer',
  'fawn',
  'cat',
  'dog',
  'human',
  'dwarf',
  'wraith',
  'demon',
  'bat',
  'hobbit',
];

/// Targets shown in the Kill picker. NPCs detected in the most-recent room
/// block (`roomTargetsProvider`) come first so the player sees what's
/// actually in front of them; then any [kCommonTargets] entries that have
/// appeared in recent MUD output bubble up in recency order; the rest of
/// the static catalogue follows in declaration order. The list never
/// shrinks — every entry in [kCommonTargets] is always present.
final commonTargetsProvider = Provider<List<String>>((ref) {
  final roomTargets = ref.watch(roomTargetsProvider);
  final recent = ref.watch(recentWordsProvider);

  final result = <String>[];
  final seen = <String>{};
  for (final t in roomTargets) {
    if (seen.add(t)) result.add(t);
  }

  final targetSet = kCommonTargets.toSet();
  for (final w in recent) {
    if (targetSet.contains(w) && seen.add(w)) result.add(w);
  }
  for (final t in kCommonTargets) {
    if (seen.add(t)) result.add(t);
  }
  return result;
});
