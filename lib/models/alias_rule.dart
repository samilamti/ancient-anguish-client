/// A command alias that expands a short input into a longer command.
///
/// Supports simple variable substitution:
/// - `$0` — everything after the alias keyword
/// - `$1`, `$2`, ... — individual space-separated arguments
///
/// Example: alias "aa" expands to "attack $1 with axe"
/// Typing "aa goblin" → sends "attack goblin with axe"
class AliasRule {
  /// Unique identifier for this alias.
  final String id;

  /// The shortcut keyword the user types.
  final String keyword;

  /// The expansion template (may contain `$0`, `$1`, `$2`, etc.).
  final String expansion;

  /// Whether this alias is currently active.
  final bool enabled;

  /// Optional description of what this alias does.
  final String? description;

  const AliasRule({
    required this.id,
    required this.keyword,
    required this.expansion,
    this.enabled = true,
    this.description,
  });

  /// Attempts to expand the given input using this alias.
  ///
  /// Returns the expanded command string if the input starts with [keyword],
  /// or `null` if this alias doesn't match.
  String? tryExpand(String input) {
    if (!enabled) return null;

    final trimmed = input.trim();
    // Check if the input starts with the keyword.
    if (!trimmed.startsWith(keyword)) return null;

    // Ensure it's an exact keyword match (not a prefix of a longer word).
    if (trimmed.length > keyword.length &&
        trimmed[keyword.length] != ' ') {
      return null;
    }

    // Extract arguments after the keyword.
    final argsString = trimmed.length > keyword.length
        ? trimmed.substring(keyword.length + 1).trim()
        : '';
    final args = argsString.isEmpty ? <String>[] : argsString.split(RegExp(r'\s+'));

    // Perform substitution.
    var result = expansion;
    result = result.replaceAll(r'$0', argsString);
    for (var i = 0; i < args.length && i < 9; i++) {
      result = result.replaceAll('\$${i + 1}', args[i]);
    }

    // Clean up any unresolved variable references.
    result = result.replaceAll(RegExp(r'\$\d'), '').trim();

    return result;
  }

  AliasRule copyWith({
    String? id,
    String? keyword,
    String? expansion,
    bool? enabled,
    String? description,
  }) {
    return AliasRule(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      expansion: expansion ?? this.expansion,
      enabled: enabled ?? this.enabled,
      description: description ?? this.description,
    );
  }

  /// Serializes to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'keyword': keyword,
        'expansion': expansion,
        'enabled': enabled,
        'description': description,
      };

  /// Deserializes from a JSON-compatible map.
  factory AliasRule.fromJson(Map<String, dynamic> json) => AliasRule(
        id: json['id'] as String,
        keyword: json['keyword'] as String,
        expansion: json['expansion'] as String,
        enabled: json['enabled'] as bool? ?? true,
        description: json['description'] as String?,
      );

  @override
  String toString() => 'AliasRule($keyword → $expansion)';
}
