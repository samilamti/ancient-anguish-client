import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recent_words_provider.dart';

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

/// The static target list, re-sorted so that any target whose name has
/// appeared in recent MUD output bubbles to the top in recency order. The
/// remaining targets keep their declaration order. The list never shrinks —
/// every entry in [kCommonTargets] is always present, just reordered.
final commonTargetsProvider = Provider<List<String>>((ref) {
  final recent = ref.watch(recentWordsProvider);
  final targetSet = kCommonTargets.toSet();
  final seen = <String>[];
  for (final w in recent) {
    if (targetSet.contains(w) && !seen.contains(w)) {
      seen.add(w);
    }
  }
  final seenSet = seen.toSet();
  final remaining = kCommonTargets.where((t) => !seenSet.contains(t));
  return [...seen, ...remaining];
});
