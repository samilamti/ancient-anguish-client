import '../../models/trigger_rule.dart';
import '../../protocol/ansi/styled_span.dart';

/// Processes terminal output lines through the configured trigger rules.
///
/// The trigger engine operates purely client-side — it never sends commands
/// to the MUD (as that would violate Ancient Anguish's rules). Instead it:
/// - Highlights matched text with custom colors.
/// - Marks lines for gagging (suppression).
/// - Notifies listeners when triggers fire (for sound/notification).
class TriggerEngine {
  final List<TriggerRule> _rules = [];

  /// Callback for when a trigger fires (e.g., to play a sound).
  void Function(TriggerRule trigger, String matchedText)? onTriggerFired;

  /// Returns an unmodifiable view of the current rules.
  List<TriggerRule> get rules => List.unmodifiable(_rules);

  /// Adds a trigger rule.
  void addRule(TriggerRule rule) {
    _rules.add(rule);
  }

  /// Removes a trigger rule by ID.
  void removeRule(String id) {
    _rules.removeWhere((r) => r.id == id);
  }

  /// Updates an existing trigger rule.
  void updateRule(TriggerRule updated) {
    final index = _rules.indexWhere((r) => r.id == updated.id);
    if (index >= 0) {
      _rules[index] = updated;
    }
  }

  /// Returns a trigger rule by ID, or null.
  TriggerRule? getRule(String id) {
    for (final rule in _rules) {
      if (rule.id == id) return rule;
    }
    return null;
  }

  /// Replaces all rules at once.
  void setRules(List<TriggerRule> rules) {
    _rules
      ..clear()
      ..addAll(rules);
  }

  /// Processes a styled line through all active triggers.
  ///
  /// Returns a [TriggerResult] indicating what happened:
  /// - [TriggerResult.styledLine] is the (possibly recolored) line.
  /// - [TriggerResult.gagged] is true if the line should be suppressed.
  /// - [TriggerResult.firedTriggers] lists all triggers that matched.
  TriggerResult processLine(StyledLine line) {
    final plainText = line.plainText;
    final firedTriggers = <TriggerRule>[];
    var gagged = false;
    StyledLine resultLine = line;

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (!rule.matches(plainText)) continue;

      firedTriggers.add(rule);

      // Notify listener (for sound playback etc.).
      onTriggerFired?.call(rule, plainText);

      switch (rule.action) {
        case TriggerAction.gag:
          gagged = true;
          break;

        case TriggerAction.highlight:
          resultLine = _applyHighlight(resultLine, rule);
          break;

        case TriggerAction.playSound:
          // Sound is handled by the callback; no visual change.
          break;

        case TriggerAction.highlightAndSound:
          resultLine = _applyHighlight(resultLine, rule);
          break;
      }
    }

    return TriggerResult(
      styledLine: resultLine,
      gagged: gagged,
      firedTriggers: firedTriggers,
    );
  }

  /// Applies color/style highlighting to the line based on the trigger rule.
  StyledLine _applyHighlight(StyledLine line, TriggerRule rule) {
    if (rule.highlightWholeLine) {
      return _highlightWholeLine(line, rule);
    }
    return _highlightMatches(line, rule);
  }

  /// Highlights the entire line with the trigger's colors.
  StyledLine _highlightWholeLine(StyledLine line, TriggerRule rule) {
    final newSpans = line.spans.map((span) {
      return StyledSpan(
        text: span.text,
        foreground: rule.highlightForeground ?? span.foreground,
        background: rule.highlightBackground ?? span.background,
        bold: rule.highlightBold || span.bold,
        italic: span.italic,
        underline: span.underline,
        strikethrough: span.strikethrough,
      );
    }).toList();
    return StyledLine(newSpans);
  }

  /// Highlights only the matched portions of the line.
  StyledLine _highlightMatches(StyledLine line, TriggerRule rule) {
    final plainText = line.plainText;
    final matches = rule.findMatches(plainText);
    if (matches.isEmpty) return line;

    // Build a set of character indices that should be highlighted.
    final highlightIndices = <int>{};
    for (final match in matches) {
      for (var i = match.start; i < match.end; i++) {
        highlightIndices.add(i);
      }
    }

    // Walk through spans, splitting them at highlight boundaries.
    final newSpans = <StyledSpan>[];
    var charIndex = 0;

    for (final span in line.spans) {
      final spanStart = charIndex;
      final spanEnd = charIndex + span.text.length;

      // Check if any characters in this span need highlighting.
      var hasHighlight = false;
      var hasNormal = false;
      for (var i = spanStart; i < spanEnd; i++) {
        if (highlightIndices.contains(i)) {
          hasHighlight = true;
        } else {
          hasNormal = true;
        }
      }

      if (!hasHighlight) {
        // No matches in this span — keep as-is.
        newSpans.add(span);
      } else if (!hasNormal) {
        // Entire span is highlighted.
        newSpans.add(_makeHighlightedSpan(span, rule));
      } else {
        // Mixed — split the span.
        _splitSpan(span, spanStart, highlightIndices, rule, newSpans);
      }

      charIndex = spanEnd;
    }

    return StyledLine(newSpans);
  }

  /// Creates a highlighted copy of a span.
  StyledSpan _makeHighlightedSpan(StyledSpan span, TriggerRule rule) {
    return StyledSpan(
      text: span.text,
      foreground: rule.highlightForeground ?? span.foreground,
      background: rule.highlightBackground ?? span.background,
      bold: rule.highlightBold || span.bold,
      italic: span.italic,
      underline: span.underline,
      strikethrough: span.strikethrough,
    );
  }

  /// Splits a span into highlighted and non-highlighted segments.
  void _splitSpan(
    StyledSpan span,
    int spanStart,
    Set<int> highlightIndices,
    TriggerRule rule,
    List<StyledSpan> output,
  ) {
    var segStart = 0;
    var isHighlighted = highlightIndices.contains(spanStart);

    for (var i = 1; i <= span.text.length; i++) {
      final currentHighlighted =
          i < span.text.length && highlightIndices.contains(spanStart + i);

      if (i == span.text.length || currentHighlighted != isHighlighted) {
        final segText = span.text.substring(segStart, i);
        if (isHighlighted) {
          output.add(StyledSpan(
            text: segText,
            foreground: rule.highlightForeground ?? span.foreground,
            background: rule.highlightBackground ?? span.background,
            bold: rule.highlightBold || span.bold,
            italic: span.italic,
            underline: span.underline,
            strikethrough: span.strikethrough,
          ));
        } else {
          output.add(StyledSpan(
            text: segText,
            foreground: span.foreground,
            background: span.background,
            bold: span.bold,
            italic: span.italic,
            underline: span.underline,
            strikethrough: span.strikethrough,
          ));
        }
        segStart = i;
        isHighlighted = currentHighlighted;
      }
    }
  }
}

/// The result of processing a line through the trigger engine.
class TriggerResult {
  /// The (possibly highlighted) styled line.
  final StyledLine styledLine;

  /// Whether the line should be suppressed from display.
  final bool gagged;

  /// All trigger rules that matched this line.
  final List<TriggerRule> firedTriggers;

  const TriggerResult({
    required this.styledLine,
    required this.gagged,
    required this.firedTriggers,
  });
}
