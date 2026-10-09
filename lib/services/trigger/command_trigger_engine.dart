import '../../models/text_link_rule.dart';

/// Fires commands in response to MUD output: the automatic sibling of a text
/// link. A rule is a [TextLinkRule] — same regex, same `$1` template — but
/// instead of turning the match into something to tap, the resolved command is
/// sent on its own.
///
/// Firing is a two-step handshake so the caller owns the timer:
///
/// 1. [onLine] checks a line of output. On a match it remembers the command
///    as *pending* and returns it; the caller waits [fireDelay].
/// 2. [takePending] hands the command back for sending, or `null` if the
///    player touched the client during the delay.
///
/// Three brakes keep it from playing the game over the player's head:
///
/// - **Idle gate.** Nothing matches until the player has left the client
///   alone for [idleThreshold]. While they are typing, tapping or scrolling,
///   output is theirs to react to.
/// - **Fire delay.** A match waits [fireDelay] before it is sent, and any
///   interaction in that window cancels it.
/// - **Shared cooldown.** After a trigger fires, no trigger at all fires for
///   [cooldown], and only one may be pending at a time. A burst of matching
///   lines therefore produces one command, and a trigger that matches its own
///   output loops at most once per cooldown instead of flooding the MUD.
///
/// [matchNow] bypasses all three for the toolbar's "Instant Triggers" mode,
/// which has its own brake instead: at most [instantRateLimit] firings in any
/// [instantRateWindow], across all rules. Matches over the limit are dropped,
/// not queued, so a runaway loop can't build a backlog that keeps sending
/// after the output that caused it has stopped.
///
/// A rule with [TextLinkRule.skipInCombat] set is passed over while the
/// caller reports `inCombat`, and a pending match from such a rule is dropped
/// if a fight has started by the time it would be sent.
///
/// Pure: the caller passes the clock and the last interaction time, so tests
/// need no timers.
class CommandTriggerEngine {
  static const idleThreshold = Duration(seconds: 3);
  static const fireDelay = Duration(seconds: 1);
  static const cooldown = Duration(seconds: 3);
  static const instantRateLimit = 2;
  static const instantRateWindow = Duration(seconds: 1);

  final List<TextLinkRule> _rules;
  String? _pending;
  DateTime? _pendingSince;
  bool _pendingSkipsCombat = false;
  DateTime? _lastFired;
  final List<DateTime> _instantFires = [];

  CommandTriggerEngine(List<TextLinkRule> rules)
      : _rules = [
          for (final rule in rules)
            if (rule.enabled && rule.regex != null) rule,
        ];

  bool get isEmpty => _rules.isEmpty;

  bool get hasPending => _pending != null;

  /// The command of the first rule matching [plainLine], now pending; `null`
  /// when nothing matches, a trigger is already pending, the cooldown is
  /// running, or the player interacted within [idleThreshold] of [now].
  String? onLine(
    String plainLine, {
    required DateTime now,
    required DateTime lastInteraction,
    bool inCombat = false,
  }) {
    if (_rules.isEmpty || _pending != null) return null;
    if (now.difference(lastInteraction) < idleThreshold) return null;
    final last = _lastFired;
    if (last != null && now.difference(last) < cooldown) return null;

    for (final rule in _rules) {
      if (inCombat && rule.skipInCombat) continue;
      final match = rule.regex!.firstMatch(plainLine);
      if (match == null) continue;
      final command = rule.resolveCommand(match);
      if (command.isEmpty) continue;
      _pending = command;
      _pendingSince = now;
      _pendingSkipsCombat = rule.skipInCombat;
      return command;
    }
    return null;
  }

  /// The command of the first rule matching [plainLine], with no idle gate,
  /// delay or cooldown, and without touching the pending/cooldown state.
  /// Returns `null` when [instantRateLimit] firings already happened within
  /// [instantRateWindow] of [now].
  String? matchNow(
    String plainLine, {
    required DateTime now,
    bool inCombat = false,
  }) {
    _instantFires
        .removeWhere((t) => now.difference(t) >= instantRateWindow);
    if (_instantFires.length >= instantRateLimit) return null;
    for (final rule in _rules) {
      if (inCombat && rule.skipInCombat) continue;
      final match = rule.regex!.firstMatch(plainLine);
      if (match == null) continue;
      final command = rule.resolveCommand(match);
      if (command.isEmpty) continue;
      _instantFires.add(now);
      return command;
    }
    return null;
  }

  /// Clears the pending trigger and returns its command to send, starting the
  /// cooldown. Returns `null` (and starts no cooldown) when nothing is
  /// pending, the player interacted after the match, or the match came from a
  /// [TextLinkRule.skipInCombat] rule and [inCombat] is now true.
  String? takePending({
    required DateTime now,
    required DateTime lastInteraction,
    bool inCombat = false,
  }) {
    final command = _pending;
    final since = _pendingSince;
    final skipsCombat = _pendingSkipsCombat;
    cancelPending();
    if (command == null || since == null) return null;
    if (lastInteraction.isAfter(since)) return null;
    if (inCombat && skipsCombat) return null;
    _lastFired = now;
    return command;
  }

  /// Drops a pending trigger without firing it (e.g. on disconnect).
  void cancelPending() {
    _pending = null;
    _pendingSince = null;
    _pendingSkipsCombat = false;
  }
}
