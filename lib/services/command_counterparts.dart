/// Maps a sent command to its logical counterpart(s) — e.g. `enter` →
/// `leave`, `open north door` → `close north door` plus `close south door`.
///
/// Used by the input bar's History button to surface common follow-up
/// commands alongside literal history entries.
///
/// To add a new pair, append to [_rules]. Each rule has a `match` regex
/// over the trimmed lower-cased input and a `build` that returns zero or
/// more counterpart strings (use the matched groups to splice the tail).
class CommandCounterparts {
  /// Direction-name lookup so `open n` and `open north` both surface
  /// `close s` / `close south` respectively. Includes diagonals and floor
  /// directions.
  static const _opposites = <String, String>{
    'n': 's', 's': 'n', 'e': 'w', 'w': 'e',
    'ne': 'sw', 'sw': 'ne', 'nw': 'se', 'se': 'nw',
    'u': 'd', 'd': 'u',
    'north': 'south', 'south': 'north',
    'east': 'west', 'west': 'east',
    'northeast': 'southwest', 'southwest': 'northeast',
    'northwest': 'southeast', 'southeast': 'northwest',
    'up': 'down', 'down': 'up',
  };

  /// One rule per recognised verb shape. Each `build` returns the
  /// counterpart strings (deduplicated by the caller).
  static final List<_Rule> _rules = [
    _Rule(
      RegExp(r'^enter(\s+.+)?$', caseSensitive: false),
      (m) => ['leave${m.group(1) ?? ''}'],
    ),
    _Rule(
      RegExp(r'^leave(\s+.+)?$', caseSensitive: false),
      (m) => ['enter${m.group(1) ?? ''}'],
    ),
    _Rule(
      RegExp(r'^open\s+(\S+)(\s+.+)?$', caseSensitive: false),
      (m) => _doorCounterparts('close', m.group(1)!, m.group(2) ?? ''),
    ),
    _Rule(
      RegExp(r'^close\s+(\S+)(\s+.+)?$', caseSensitive: false),
      (m) => _doorCounterparts('open', m.group(1)!, m.group(2) ?? ''),
    ),
  ];

  /// Returns the counterpart commands for [command], or an empty list if
  /// none match. Order is preserved; duplicates are removed.
  static List<String> counterpartsOf(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return const [];
    final results = <String>{};
    for (final rule in _rules) {
      final m = rule.match.firstMatch(trimmed);
      if (m == null) continue;
      for (final out in rule.build(m)) {
        if (out.isNotEmpty) results.add(out);
      }
    }
    return results.toList();
  }

  static List<String> _doorCounterparts(
    String verb,
    String firstArg,
    String rest,
  ) {
    final primary = '$verb $firstArg$rest';
    final opp = _opposites[firstArg.toLowerCase()];
    if (opp == null) return [primary];
    return [primary, '$verb $opp$rest'];
  }
}

class _Rule {
  final RegExp match;
  final List<String> Function(Match m) build;

  _Rule(this.match, this.build);
}
