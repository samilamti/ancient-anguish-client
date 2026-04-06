import '../../models/alias_rule.dart';

/// Expands user input commands through alias rules before sending to the MUD.
///
/// Supports variable substitution in alias expansions:
/// - `$0` — everything after the alias keyword
/// - `$1`, `$2`, ... — individual space-separated arguments
///
/// Also supports command chaining via semicolons, allowing one alias
/// to expand into multiple commands.
class AliasEngine {
  final List<AliasRule> _rules = [];

  /// Maximum expansion depth to prevent infinite alias loops.
  static const int maxExpansionDepth = 10;

  /// Returns an unmodifiable view of the current rules.
  List<AliasRule> get rules => List.unmodifiable(_rules);

  /// Adds an alias rule.
  void addRule(AliasRule rule) {
    _rules.add(rule);
  }

  /// Removes an alias rule by ID.
  void removeRule(String id) {
    _rules.removeWhere((r) => r.id == id);
  }

  /// Updates an existing alias rule.
  void updateRule(AliasRule updated) {
    final index = _rules.indexWhere((r) => r.id == updated.id);
    if (index >= 0) {
      _rules[index] = updated;
    }
  }

  /// Returns an alias rule by ID, or null.
  AliasRule? getRule(String id) {
    for (final rule in _rules) {
      if (rule.id == id) return rule;
    }
    return null;
  }

  /// Replaces all rules at once.
  void setRules(List<AliasRule> rules) {
    _rules
      ..clear()
      ..addAll(rules);
  }

  /// Expands the given input through all active alias rules.
  ///
  /// Returns a list of commands to send. If no alias matches, returns a
  /// single-element list containing the original input unchanged.
  ///
  /// Supports semicolon-separated command chains in both input and
  /// alias expansions. An alias cannot re-trigger itself (prevents
  /// infinite loops when expansion starts with the same keyword).
  List<String> expand(String input) {
    return _expandWithDepth(input, 0, const {});
  }

  List<String> _expandWithDepth(
    String input,
    int depth,
    Set<String> usedAliasIds,
  ) {
    if (depth >= maxExpansionDepth) return [input];

    final trimmed = input.trim();
    if (trimmed.isEmpty) return [trimmed];

    // Handle semicolon-separated commands.
    if (trimmed.contains(';')) {
      final parts = trimmed.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty);
      final results = <String>[];
      for (final part in parts) {
        results.addAll(_expandWithDepth(part, depth, usedAliasIds));
      }
      return results;
    }

    // Try each alias rule (skipping already-used ones to prevent self-loops).
    for (final rule in _rules) {
      if (usedAliasIds.contains(rule.id)) continue;
      final expanded = rule.tryExpand(trimmed);
      if (expanded != null) {
        // Recursively expand, but mark this alias as used.
        return _expandWithDepth(
          expanded,
          depth + 1,
          {...usedAliasIds, rule.id},
        );
      }
    }

    return [trimmed];
  }

  /// Returns true if the given input would be expanded by an alias.
  bool hasMatch(String input) {
    final trimmed = input.trim();
    for (final rule in _rules) {
      if (rule.tryExpand(trimmed) != null) return true;
    }
    return false;
  }

  /// Creates a set of useful default aliases for Ancient Anguish.
  static List<AliasRule> defaultAliases() {
    return [
      AliasRule(
        id: 'alias_ga',
        keyword: 'ga',
        expansion: 'get all',
        description: 'Get all items from the ground',
      ),
      AliasRule(
        id: 'alias_gac',
        keyword: 'gac',
        expansion: 'get all from corpse',
        description: 'Loot a corpse',
      ),
      AliasRule(
        id: 'alias_sc',
        keyword: 'sc',
        expansion: 'score',
        description: 'Show score',
      ),
      AliasRule(
        id: 'alias_eq',
        keyword: 'eq',
        expansion: 'equipment',
        description: 'Show worn equipment',
      ),
      AliasRule(
        id: 'alias_hp',
        keyword: 'hp',
        expansion: 'health',
        description: 'Show health status',
      ),
      AliasRule(
        id: 'alias_k',
        keyword: 'k',
        expansion: 'kill \$1',
        description: 'Kill target — usage: k goblin',
      ),
      AliasRule(
        id: 'alias_c',
        keyword: 'c',
        expansion: 'cast \$0',
        description: 'Cast spell — usage: c fireball at goblin',
      ),
    ];
  }
}
