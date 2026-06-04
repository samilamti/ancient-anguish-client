import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A prefix→completion rule for the mobile auto-completion bar.
///
/// When the user's input matches [trigger], the bar offers [completion] as a
/// tappable suggestion. [completion] is inserted verbatim — including any
/// trailing space (e.g. `dotimes 30 `) so the user can keep typing the
/// repeated command.
class CompletionRule {
  /// The exact text the user types to surface this completion.
  final String trigger;

  /// The full text inserted when the suggestion is accepted.
  final String completion;

  const CompletionRule({required this.trigger, required this.completion});
}

/// Seed rules mirroring desktop power-user shorthands. More can be appended
/// here (or the provider overridden) without touching the UI.
const List<CompletionRule> kDefaultCompletionRules = [
  CompletionRule(trigger: 'dot', completion: 'dotimes 30 '),
  CompletionRule(trigger: 'po', completion: 'powerup'),
  CompletionRule(trigger: 'i t', completion: 'i trunk -c'),
];

/// The active completion rules. A plain [Provider] today; swap for a persisted
/// notifier if user-editable rules are wanted later — [matchCompletions] and
/// the UI consume this list either way.
final completionRulesProvider = Provider<List<CompletionRule>>(
  (ref) => kDefaultCompletionRules,
);

/// Returns the rules whose [CompletionRule.trigger] matches [input].
///
/// Matching mirrors how desktop TAB completion feels: the trimmed,
/// case-insensitive input must equal a rule's trigger. Returns an empty list
/// when nothing matches (including for empty input). Order follows [rules].
List<CompletionRule> matchCompletions(
  List<CompletionRule> rules,
  String input,
) {
  final key = input.trim().toLowerCase();
  if (key.isEmpty) return const [];
  return rules.where((r) => r.trigger.toLowerCase() == key).toList();
}
