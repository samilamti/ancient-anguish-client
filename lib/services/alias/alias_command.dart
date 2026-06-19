/// Parser for the quick-alias-creation command `#al <alias> <expansion>`.
///
/// Typed into the main command input, `#al bt buy tekillya;drink tekillya`
/// creates an alias `bt` that expands to `buy tekillya;drink tekillya`. The
/// command is handled entirely client-side — it never reaches the MUD — and
/// the semicolon stays in the expansion (chaining is resolved later, at
/// expansion time, by the alias engine).
class AliasCommand {
  /// Accepted trigger tokens, matched case-insensitively as a standalone word.
  /// Longest first so `#alias` is preferred over its `#al` prefix.
  static const List<String> triggers = ['#alias', '#al'];

  /// The alias keyword to create (null when the command was malformed).
  final String? keyword;

  /// The expansion the keyword maps to (null when malformed).
  final String? expansion;

  /// A usage message, non-null only when the `#al` syntax was used but is
  /// incomplete (e.g. missing the expansion).
  final String? error;

  const AliasCommand._({this.keyword, this.expansion, this.error});

  /// Whether this parsed into a usable keyword + expansion.
  bool get isValid => error == null && keyword != null && expansion != null;

  static final RegExp _split = RegExp(r'^(\S+)\s+(.+)$', dotAll: true);

  /// Parses [input].
  ///
  /// Returns `null` when [input] is not an `#al` command at all (so the caller
  /// sends it to the MUD normally). Otherwise returns a result that is either
  /// [isValid] (keyword + expansion) or carries a usage [error].
  static AliasCommand? parse(String input) {
    final trimmed = input.trimLeft();
    final triggerLen = _triggerLength(trimmed);
    if (triggerLen < 0) return null;

    final rest = trimmed.substring(triggerLen).trim();
    if (rest.isEmpty) {
      return const AliasCommand._(error: 'Usage: #al <alias> <expansion>');
    }

    final match = _split.firstMatch(rest);
    if (match == null) {
      // A single token after `#al` — a keyword with no expansion.
      return AliasCommand._(
        error: 'Usage: #al <alias> <expansion> '
            '(no expansion given for "$rest")',
      );
    }

    return AliasCommand._(
      keyword: match.group(1),
      expansion: match.group(2)!.trim(),
    );
  }

  /// Returns the length of the trigger token [trimmed] starts with (as a
  /// standalone word — the whole string is the trigger, or it's immediately
  /// followed by whitespace), or -1 if none match. `#also`, `#alpha` etc. do
  /// NOT match.
  static int _triggerLength(String trimmed) {
    final lower = trimmed.toLowerCase();
    for (final t in triggers) {
      if (lower.length < t.length) continue;
      if (lower.substring(0, t.length) != t) continue;
      if (lower.length == t.length) return t.length;
      final next = trimmed[t.length];
      if (next == ' ' || next == '\t') return t.length;
    }
    return -1;
  }
}
