/// A rare, worth-remembering game event shown in the Achievements tab.
class Achievement {
  final String icon;
  final String text;
  final DateTime timestamp;

  const Achievement({
    required this.icon,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'icon': icon,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  static Achievement? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = json['text'];
    final ts = DateTime.tryParse(json['timestamp']?.toString() ?? '');
    if (text is! String || ts == null) return null;
    return Achievement(
      icon: json['icon'] as String? ?? '🎉',
      text: text,
      timestamp: ts,
    );
  }
}

/// Recognises the MUD lines that count as achievements.
///
/// Each rule is a whole-line pattern plus the icon to show beside it. Add a
/// rule here to capture a new kind of event; nothing else needs to change.
class AchievementParser {
  static final List<(RegExp, String)> _rules = [
    // "Your skill in Spear has gone up!"
    (RegExp(r'^Your skill in .+ has gone up!$'), '🎉'),
  ];

  /// The achievement [plainText] announces, or null when it is an ordinary line.
  static Achievement? match(String plainText, {DateTime? now}) {
    final line = plainText.trim();
    for (final (pattern, icon) in _rules) {
      if (pattern.hasMatch(line)) {
        return Achievement(
          icon: icon,
          text: line,
          timestamp: now ?? DateTime.now(),
        );
      }
    }
    return null;
  }
}
