/// A text-to-link rule: when the [pattern] regex matches a line of MUD
/// output, the matched substring becomes a tappable link; tapping it sends
/// the [commandTemplate] (after `$1`, `$2`, ... substitution from the
/// regex's capture groups) to the MUD.
///
/// Examples:
/// - pattern `^You must be standing\.$`, template `stand`
/// - pattern `The (\w+) door is closed\.`, template `open $1 door`
class TextLinkRule {
  /// Stable id used for persistence and editing.
  final String id;

  /// Human-readable name shown in the config UI.
  final String name;

  /// Source regex string. Persisted as text so users can edit it.
  final String pattern;

  /// Command template with `$1`, `$2`, ... placeholders for capture groups.
  final String commandTemplate;

  /// Whether this rule is currently active.
  final bool enabled;

  /// Whether the pattern matches case-sensitively. Defaults to `true` to
  /// preserve the behaviour of hand-written and default rules; generated
  /// rules (e.g. the Kill picker's target links) opt into `false`.
  final bool caseSensitive;

  const TextLinkRule({
    required this.id,
    required this.name,
    required this.pattern,
    required this.commandTemplate,
    this.enabled = true,
    this.caseSensitive = true,
  });

  /// Lazily-compiled regex. Returns null if the pattern fails to compile so
  /// a broken rule degrades gracefully (skipped, not crash).
  RegExp? get regex {
    try {
      return RegExp(pattern, caseSensitive: caseSensitive);
    } catch (_) {
      return null;
    }
  }

  /// Substitutes the regex match's groups into [commandTemplate], replacing
  /// `$0` with the entire match, `$1`..`$9` with individual capture groups.
  /// Missing groups become empty strings; trailing whitespace is trimmed.
  String resolveCommand(Match match) {
    var result = commandTemplate;
    result = result.replaceAll(r'$0', match.group(0) ?? '');
    final groupCount = match.groupCount;
    for (var i = 1; i <= 9; i++) {
      final value = i <= groupCount ? (match.group(i) ?? '') : '';
      result = result.replaceAll('\$$i', value);
    }
    return result.trim();
  }

  TextLinkRule copyWith({
    String? id,
    String? name,
    String? pattern,
    String? commandTemplate,
    bool? enabled,
    bool? caseSensitive,
  }) {
    return TextLinkRule(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      commandTemplate: commandTemplate ?? this.commandTemplate,
      enabled: enabled ?? this.enabled,
      caseSensitive: caseSensitive ?? this.caseSensitive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pattern': pattern,
        'commandTemplate': commandTemplate,
        'enabled': enabled,
        'caseSensitive': caseSensitive,
      };

  factory TextLinkRule.fromJson(Map<String, dynamic> json) => TextLinkRule(
        id: json['id'] as String,
        name: json['name'] as String,
        pattern: json['pattern'] as String,
        commandTemplate: json['commandTemplate'] as String,
        enabled: json['enabled'] as bool? ?? true,
        caseSensitive: json['caseSensitive'] as bool? ?? true,
      );

  @override
  String toString() =>
      'TextLinkRule($name: /$pattern/ → "$commandTemplate")';
}

/// Built-in defaults seeded the first time the user opens the rules
/// screen. Mirrors the examples in the original feature request.
class DefaultTextLinkRules {
  static List<TextLinkRule> all() => const [
        TextLinkRule(
          id: 'tlr_default_stand',
          name: 'Stand up',
          pattern: r'You must be standing\.',
          commandTemplate: 'stand',
        ),
        TextLinkRule(
          id: 'tlr_default_open_door',
          name: 'Open closed door',
          pattern: r'The (\w+) door is closed\.',
          commandTemplate: r'open $1 door',
        ),
        TextLinkRule(
          id: 'tlr_default_accept',
          name: 'Accept',
          pattern: r"'accept'",
          commandTemplate: 'accept',
        ),
        TextLinkRule(
          id: 'tlr_default_read_rules',
          name: 'Read rules',
          pattern: r"'read rules'",
          commandTemplate: 'read rules',
        ),
      ];
}
