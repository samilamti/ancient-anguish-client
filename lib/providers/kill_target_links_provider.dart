import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/terminal_colors.dart';
import '../services/parser/kill_target_link_processor.dart';
import 'common_targets_provider.dart';
import 'room_targets_provider.dart';
import 'settings_provider.dart';

/// Colour used for kill-target links in the terminal — a reddish tint that
/// separates "this is a thing you can attack" from ordinary text-link rules,
/// which keep their surrounding ANSI colour.
const killTargetLinkColor = TerminalColors.brightRed;

/// The word set the catalogue scan matches against: every NPC detected in the
/// current room plus the static catalogue the Kill picker always offers.
///
/// Deliberately derived from [roomTargetsProvider] and [kCommonTargets] only,
/// *not* from `commonTargetsProvider` — that one also watches recent words,
/// which change on nearly every line of output and would rebuild the
/// alternation constantly for an identical word set.
final killTargetWordsProvider = Provider<List<String>>((ref) {
  final roomTargets = ref.watch(roomTargetsProvider);
  final words = <String>{...roomTargets, ...kCommonTargets};
  // Sorted so the value is stable for a given set.
  final sorted = words.toList()..sort();
  return List.unmodifiable(sorted);
});

/// Renders Automatic Kill List targets in MUD output as tappable, reddish
/// `kill <target>` links. See [KillTargetLinkProcessor] for the matching
/// rules; it runs *after* the user's own text-link rules in the buffer
/// pipeline, so a hand-written rule always wins a contested region.
///
/// Words on the user's ignore list (long-press a red link to add one) are
/// dropped here, which is what keeps a stubborn false positive from painting
/// the screen red until the static blocklists learn about it.
final killTargetLinkProcessorProvider =
    Provider<KillTargetLinkProcessor>((ref) {
  return KillTargetLinkProcessor(
    ref.watch(killTargetWordsProvider),
    linkColor: killTargetLinkColor,
    ignored: ref.watch(
      settingsProvider.select((s) => s.ignoredKillTargets),
    ),
  );
});
