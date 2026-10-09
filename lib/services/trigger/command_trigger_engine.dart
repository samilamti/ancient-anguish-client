import '../../models/meter_condition.dart';
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
/// Rules can opt out of situations: [TextLinkRule.skipInCombat] while the
/// caller reports `inCombat`, [TextLinkRule.skipWhileMoving] while it reports
/// `moving`. Such a rule is passed over, and its pending match is dropped if
/// the situation has arisen by the time it would be sent.
///
/// Meter triggers ([TextLinkRule.meter]) go through [onVitals] and
/// [matchVitalsNow] instead of the line entry points, with the same brakes:
/// one pending slot, one cooldown and one instant rate limit shared by both
/// kinds. They are kept out of line matching entirely, since their empty
/// pattern would match every line.
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
  final List<TextLinkRule> _meterRules;
  String? _pending;
  DateTime? _pendingSince;
  TextLinkRule? _pendingRule;
  DateTime? _lastFired;
  final List<DateTime> _instantFires = [];

  CommandTriggerEngine(List<TextLinkRule> rules)
      : _rules = [
          for (final rule in rules)
            if (rule.enabled && !rule.isMeterTrigger && rule.regex != null)
              rule,
        ],
        _meterRules = [
          for (final rule in rules)
            if (rule.enabled && rule.meter?.isValid == true) rule,
        ];

  bool get isEmpty => _rules.isEmpty && _meterRules.isEmpty;

  bool get hasMeterRules => _meterRules.isNotEmpty;

  bool get hasPending => _pending != null;

  /// The command of the first rule matching [plainLine], now pending; `null`
  /// when nothing matches, a trigger is already pending, the cooldown is
  /// running, or the player interacted within [idleThreshold] of [now].
  String? onLine(
    String plainLine, {
    required DateTime now,
    required DateTime lastInteraction,
    bool inCombat = false,
    bool moving = false,
  }) {
    if (_rules.isEmpty || !_canQueue(now, lastInteraction)) return null;
    final hit = _lineHit(plainLine, inCombat, moving);
    return hit == null ? null : _queue(hit, now);
  }

  /// [onLine] for meters: the command of the first meter trigger whose band
  /// was entered between [before] and [after], now pending. Same gates.
  String? onVitals(
    VitalsReading before,
    VitalsReading after, {
    required DateTime now,
    required DateTime lastInteraction,
    bool inCombat = false,
    bool moving = false,
  }) {
    if (_meterRules.isEmpty || !_canQueue(now, lastInteraction)) return null;
    final hit = _meterHit(before, after, inCombat, moving);
    return hit == null ? null : _queue(hit, now);
  }

  bool _canQueue(DateTime now, DateTime lastInteraction) {
    if (_pending != null) return false;
    if (now.difference(lastInteraction) < idleThreshold) return false;
    final last = _lastFired;
    return last == null || now.difference(last) >= cooldown;
  }

  String _queue((TextLinkRule, String) hit, DateTime now) {
    _pending = hit.$2;
    _pendingSince = now;
    _pendingRule = hit.$1;
    return hit.$2;
  }

  (TextLinkRule, String)? _lineHit(
      String plainLine, bool inCombat, bool moving) {
    for (final rule in _rules) {
      if (_sitsOut(rule, inCombat, moving)) continue;
      final match = rule.regex!.firstMatch(plainLine);
      if (match == null) continue;
      final command = rule.resolveCommand(match);
      if (command.isEmpty) continue;
      return (rule, command);
    }
    return null;
  }

  (TextLinkRule, String)? _meterHit(VitalsReading before, VitalsReading after,
      bool inCombat, bool moving) {
    for (final rule in _meterRules) {
      if (_sitsOut(rule, inCombat, moving)) continue;
      if (!rule.meter!.firesOn(before, after)) continue;
      // No match to substitute from; `$1` and friends resolve to nothing.
      final command = rule.resolveCommand(_noMatch);
      if (command.isEmpty) continue;
      return (rule, command);
    }
    return null;
  }

  static final Match _noMatch = RegExp('').firstMatch('')!;

  /// The command of the first rule matching [plainLine], with no idle gate,
  /// delay or cooldown, and without touching the pending/cooldown state.
  /// Returns `null` when [instantRateLimit] firings already happened within
  /// [instantRateWindow] of [now].
  String? matchNow(
    String plainLine, {
    required DateTime now,
    bool inCombat = false,
    bool moving = false,
  }) {
    if (!_instantAllowed(now)) return null;
    final hit = _lineHit(plainLine, inCombat, moving);
    if (hit == null) return null;
    _instantFires.add(now);
    return hit.$2;
  }

  /// [matchNow] for meters, sharing its rate limit.
  String? matchVitalsNow(
    VitalsReading before,
    VitalsReading after, {
    required DateTime now,
    bool inCombat = false,
    bool moving = false,
  }) {
    if (!_instantAllowed(now)) return null;
    final hit = _meterHit(before, after, inCombat, moving);
    if (hit == null) return null;
    _instantFires.add(now);
    return hit.$2;
  }

  bool _instantAllowed(DateTime now) {
    _instantFires
        .removeWhere((t) => now.difference(t) >= instantRateWindow);
    return _instantFires.length < instantRateLimit;
  }

  /// Clears the pending trigger and returns its command to send, starting the
  /// cooldown. Returns `null` (and starts no cooldown) when nothing is
  /// pending, the player interacted after the match, or the matching rule
  /// now sits out because of [inCombat] or [moving].
  String? takePending({
    required DateTime now,
    required DateTime lastInteraction,
    bool inCombat = false,
    bool moving = false,
  }) {
    final command = _pending;
    final since = _pendingSince;
    final rule = _pendingRule;
    cancelPending();
    if (command == null || since == null || rule == null) return null;
    if (lastInteraction.isAfter(since)) return null;
    if (_sitsOut(rule, inCombat, moving)) return null;
    _lastFired = now;
    return command;
  }

  /// Drops a pending trigger without firing it (e.g. on disconnect).
  void cancelPending() {
    _pending = null;
    _pendingSince = null;
    _pendingRule = null;
  }

  static bool _sitsOut(TextLinkRule rule, bool inCombat, bool moving) =>
      (inCombat && rule.skipInCombat) || (moving && rule.skipWhileMoving);
}
