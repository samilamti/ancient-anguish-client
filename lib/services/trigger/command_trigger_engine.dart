import '../../models/text_link_rule.dart';

/// Fires commands in response to MUD output: the automatic sibling of a text
/// link. A rule is a [TextLinkRule] — same regex, same `$1` template — but
/// instead of turning the match into something to tap, the resolved command is
/// sent on its own.
///
/// Two brakes keep it from playing the game over the player's head:
///
/// - **Idle gate.** Nothing fires until the player has left the client alone
///   for [idleThreshold]. While they are typing, tapping or scrolling, output
///   is theirs to react to.
/// - **Per-rule cooldown.** A rule whose command produces the very line it
///   matches would otherwise loop as fast as the MUD answers. [cooldown] caps
///   each rule to one firing per window, which still lets a deliberate loop
///   ("You finish digging." → `dig`) run, just not flood the connection.
///
/// Pure: the caller passes the clock and the last interaction time, so tests
/// need no timers.
class CommandTriggerEngine {
  static const idleThreshold = Duration(seconds: 3);
  static const cooldown = Duration(seconds: 1);

  final List<TextLinkRule> _rules;
  final Map<String, DateTime> _lastFired = {};

  CommandTriggerEngine(List<TextLinkRule> rules)
      : _rules = [
          for (final rule in rules)
            if (rule.enabled && rule.regex != null) rule,
        ];

  bool get isEmpty => _rules.isEmpty;

  /// Commands to send for one line of plain MUD output, in rule order. Empty
  /// when the player interacted within [idleThreshold] of [now].
  List<String> commandsFor(
    String plainLine, {
    required DateTime now,
    required DateTime lastInteraction,
  }) {
    if (_rules.isEmpty) return const [];
    if (now.difference(lastInteraction) < idleThreshold) return const [];

    final out = <String>[];
    for (final rule in _rules) {
      final match = rule.regex!.firstMatch(plainLine);
      if (match == null) continue;
      final last = _lastFired[rule.id];
      if (last != null && now.difference(last) < cooldown) continue;
      final command = rule.resolveCommand(match);
      if (command.isEmpty) continue;
      _lastFired[rule.id] = now;
      out.add(command);
    }
    return out;
  }
}
