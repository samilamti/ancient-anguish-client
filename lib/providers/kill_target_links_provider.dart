import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/terminal_colors.dart';
import '../models/text_link_rule.dart';
import '../services/parser/text_link_processor.dart';
import 'common_targets_provider.dart';
import 'room_targets_provider.dart';

/// Colour used for kill-target links in the terminal — a reddish tint that
/// separates "this is a thing you can attack" from ordinary text-link rules,
/// which keep their surrounding ANSI colour.
const killTargetLinkColor = TerminalColors.brightRed;

/// The word set the Automatic Kill List links against: every NPC detected in
/// the current room plus the static catalogue the Kill picker always offers.
///
/// Deliberately derived from [roomTargetsProvider] and [kCommonTargets] only,
/// *not* from `commonTargetsProvider` — that one also watches recent words,
/// which change on nearly every line of output and would rebuild the regex
/// constantly for an identical word set.
final killTargetWordsProvider = Provider<List<String>>((ref) {
  final roomTargets = ref.watch(roomTargetsProvider);
  final words = <String>{...roomTargets, ...kCommonTargets};
  // Sorted so the provider's value is stable for a given set — an unchanged
  // set then compares equal and doesn't rebuild the processor below.
  final sorted = words.toList()..sort();
  return List.unmodifiable(sorted);
});

/// Promotes Automatic Kill List targets appearing in MUD output to tappable
/// `kill <target>` links, tinted [killTargetLinkColor].
///
/// All targets share a single alternation regex, so a line is scanned once
/// regardless of catalogue size. Runs *after* the user's own text-link rules
/// in the buffer pipeline, so a hand-written rule always wins a contested
/// region (the processor skips spans that already carry a command or URL).
final killTargetLinkProcessorProvider = Provider<TextLinkProcessor>((ref) {
  final words = ref.watch(killTargetWordsProvider);
  if (words.isEmpty) return TextLinkProcessor(const []);

  // Word-bounded alternation over escaped literals; longest-first so a
  // multi-word target isn't cut short by a shorter one sharing its prefix.
  final byLength = [...words]
    ..sort((a, b) => b.length.compareTo(a.length));
  final alternation = byLength.map(RegExp.escape).join('|');

  return TextLinkProcessor(
    [
      TextLinkRule(
        id: 'kill_target_links',
        name: 'Automatic Kill List targets',
        pattern: '\\b($alternation)\\b',
        commandTemplate: r'kill $1',
        caseSensitive: false,
      ),
    ],
    linkColor: killTargetLinkColor,
  );
});
