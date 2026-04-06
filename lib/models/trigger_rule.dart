import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A client-side trigger rule that matches patterns in MUD output.
///
/// Ancient Anguish prohibits triggers that auto-send commands, so triggers
/// here only perform client-side actions: highlighting text, playing sounds,
/// or showing notifications.
class TriggerRule {
  /// Unique identifier for this trigger.
  final String id;

  /// Human-readable name for this trigger.
  final String name;

  /// Regex pattern to match against incoming lines.
  final String pattern;

  /// Whether this trigger is currently active.
  final bool enabled;

  /// The action type this trigger performs.
  final TriggerAction action;

  /// Highlight foreground color (for [TriggerAction.highlight]).
  final Color? highlightForeground;

  /// Highlight background color (for [TriggerAction.highlight]).
  final Color? highlightBackground;

  /// Whether to make matched text bold (for [TriggerAction.highlight]).
  final bool highlightBold;

  /// Sound file path to play (for [TriggerAction.playSound]).
  final String? soundPath;

  /// Whether to apply to the entire line or just the matched portion.
  final bool highlightWholeLine;

  /// Compiled regex (lazily built from [pattern]).
  RegExp? _compiledPattern;

  TriggerRule({
    required this.id,
    required this.name,
    required this.pattern,
    this.enabled = true,
    this.action = TriggerAction.highlight,
    this.highlightForeground,
    this.highlightBackground,
    this.highlightBold = false,
    this.soundPath,
    this.highlightWholeLine = false,
  });

  /// Returns the compiled regex, or null if the pattern is invalid.
  RegExp? get compiledPattern {
    if (_compiledPattern != null) return _compiledPattern;
    try {
      _compiledPattern = RegExp(pattern, caseSensitive: false);
      return _compiledPattern;
    } catch (e) {
      debugPrint('TriggerRule.compiledPattern error: $e');
      return null;
    }
  }

  /// Tests whether this trigger matches the given line text.
  bool matches(String lineText) {
    if (!enabled) return false;
    final regex = compiledPattern;
    if (regex == null) return false;
    return regex.hasMatch(lineText);
  }

  /// Returns all match ranges in the given text.
  List<TriggerMatch> findMatches(String lineText) {
    if (!enabled) return const [];
    final regex = compiledPattern;
    if (regex == null) return const [];
    return regex.allMatches(lineText).map((m) {
      return TriggerMatch(
        start: m.start,
        end: m.end,
        matchedText: m.group(0) ?? '',
        trigger: this,
      );
    }).toList();
  }

  TriggerRule copyWith({
    String? id,
    String? name,
    String? pattern,
    bool? enabled,
    TriggerAction? action,
    Color? highlightForeground,
    Color? highlightBackground,
    bool? highlightBold,
    String? soundPath,
    bool? highlightWholeLine,
  }) {
    return TriggerRule(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      enabled: enabled ?? this.enabled,
      action: action ?? this.action,
      highlightForeground: highlightForeground ?? this.highlightForeground,
      highlightBackground: highlightBackground ?? this.highlightBackground,
      highlightBold: highlightBold ?? this.highlightBold,
      soundPath: soundPath ?? this.soundPath,
      highlightWholeLine: highlightWholeLine ?? this.highlightWholeLine,
    );
  }

  /// Serializes to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pattern': pattern,
        'enabled': enabled,
        'action': action.name,
        'highlightForeground': highlightForeground?.toARGB32(),
        'highlightBackground': highlightBackground?.toARGB32(),
        'highlightBold': highlightBold,
        'soundPath': soundPath,
        'highlightWholeLine': highlightWholeLine,
      };

  /// Deserializes from a JSON-compatible map.
  factory TriggerRule.fromJson(Map<String, dynamic> json) => TriggerRule(
        id: json['id'] as String,
        name: json['name'] as String,
        pattern: json['pattern'] as String,
        enabled: json['enabled'] as bool? ?? true,
        action: TriggerAction.values.byName(
          json['action'] as String? ?? 'highlight',
        ),
        highlightForeground: json['highlightForeground'] != null
            ? Color(json['highlightForeground'] as int)
            : null,
        highlightBackground: json['highlightBackground'] != null
            ? Color(json['highlightBackground'] as int)
            : null,
        highlightBold: json['highlightBold'] as bool? ?? false,
        soundPath: json['soundPath'] as String?,
        highlightWholeLine: json['highlightWholeLine'] as bool? ?? false,
      );

  @override
  String toString() => 'TriggerRule($name, /$pattern/, $action)';
}

/// The kind of action a trigger performs when matched.
enum TriggerAction {
  /// Highlight matched text with a custom color/style.
  highlight,

  /// Play a sound file when the pattern is matched.
  playSound,

  /// Both highlight and play sound.
  highlightAndSound,

  /// Suppress the line from display (gag).
  gag,
}

/// Represents a single match of a trigger pattern within a line.
class TriggerMatch {
  final int start;
  final int end;
  final String matchedText;
  final TriggerRule trigger;

  const TriggerMatch({
    required this.start,
    required this.end,
    required this.matchedText,
    required this.trigger,
  });
}
