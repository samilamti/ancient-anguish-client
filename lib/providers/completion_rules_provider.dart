import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recent_words_provider.dart';

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

/// One tappable Hint in the mobile completion bar.
///
/// [label] is what the chip shows; [resolvedInput] is the full input line the
/// hint produces. A hint whose [resolvedInput] ends in whitespace is a
/// *partial template* (e.g. `dotimes 30 `) — the user still has to finish it,
/// so tapping fills the input instead of sending. See [sendsOnTap].
class CompletionHint {
  /// Chip caption — the rule's completion, or the completed word.
  final String label;

  /// The complete input line produced by accepting this hint.
  final String resolvedInput;

  const CompletionHint({required this.label, required this.resolvedInput});

  /// Whether tapping this hint should fire the command straight at the MUD.
  /// False for partial templates, which fill the input for further typing.
  bool get sendsOnTap => resolvedInput.trimRight() == resolvedInput;

  @override
  bool operator ==(Object other) =>
      other is CompletionHint &&
      other.label == label &&
      other.resolvedInput == resolvedInput;

  @override
  int get hashCode => Object.hash(label, resolvedInput);
}

/// Builds the mobile Hint list for [input] — the tap-able port of desktop
/// TAB completion.
///
/// Two sources, in priority order:
/// 1. [rules] whose trigger equals the whole trimmed input (`po` → `powerup`,
///    `i t` → `i trunk -c`).
/// 2. Prefix completion of the word being typed against [recentWords] — the
///    same corpus desktop's TAB key cycles through. The completed word is
///    spliced back into the line, so `kill gob` offers `kill goblin`.
///
/// Word hints need at least [minWordPrefix] characters to avoid flooding the
/// bar, are capped at [maxWordHints], and never repeat a line already offered
/// by a rule. Returns an empty list when nothing matches, so the bar collapses.
List<CompletionHint> buildCompletionHints({
  required List<CompletionRule> rules,
  required List<String> recentWords,
  required String input,
  int maxWordHints = 6,
  int minWordPrefix = 2,
}) {
  final hints = <CompletionHint>[];
  final seen = <String>{};

  void addHint(String label, String resolved) {
    if (resolved.isEmpty || !seen.add(resolved)) return;
    hints.add(CompletionHint(label: label, resolvedInput: resolved));
  }

  for (final rule in matchCompletions(rules, input)) {
    addHint(rule.completion.trimRight(), rule.completion);
  }

  // The word under the cursor is the tail after the last space. An input
  // ending in a space has no partial word, so no word hints apply.
  final wordStart = input.lastIndexOf(' ') + 1;
  final prefix = input.substring(wordStart);
  if (prefix.length < minWordPrefix) return hints;

  final head = input.substring(0, wordStart);
  final lowerPrefix = prefix.toLowerCase();
  var added = 0;
  for (final word in completionsFor(recentWords, lowerPrefix)) {
    if (word == lowerPrefix) continue; // Already fully typed.
    addHint(word, '$head$word');
    if (++added >= maxWordHints) break;
  }

  return hints;
}
