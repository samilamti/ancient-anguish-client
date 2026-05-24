import '../../models/text_link_rule.dart';
import '../../protocol/ansi/styled_span.dart';

/// Applies a list of [TextLinkRule]s to a [StyledLine], promoting matched
/// substrings to tappable command-link spans (see [StyledSpan.command]).
///
/// Operates on the line's plain text. The first rule that matches a given
/// region wins; subsequent rules don't re-scan inside a region already
/// claimed by an earlier rule (so overlapping patterns stay deterministic
/// and the user can prioritise via list order).
class TextLinkProcessor {
  final List<TextLinkRule> _rules;
  // Pre-compiled regexes paired with their owning rule. Patterns that fail
  // to compile are dropped at construction time so the hot path never has
  // to handle nulls.
  final List<_CompiledRule> _compiled;

  TextLinkProcessor(this._rules)
      : _compiled = _rules
            .where((r) => r.enabled)
            .map((r) {
              final re = r.regex;
              return re == null ? null : _CompiledRule(r, re);
            })
            .whereType<_CompiledRule>()
            .toList(growable: false);

  bool get isEmpty => _compiled.isEmpty;

  /// Returns the rule list as-is — for tests and config UI introspection.
  List<TextLinkRule> get rules => _rules;

  /// Processes [line], returning the original instance when no rule
  /// matched (cheap reference equality lets the buffer skip rebuilds).
  StyledLine processLine(StyledLine line) {
    if (_compiled.isEmpty) return line;

    final plain = line.plainText;
    if (plain.isEmpty) return line;

    // Collect non-overlapping matches across all rules. Sort by start,
    // then drop any that overlap an earlier accepted match.
    final hits = <_Hit>[];
    for (final cr in _compiled) {
      for (final m in cr.regex.allMatches(plain)) {
        if (m.start == m.end) continue; // Zero-width, skip.
        hits.add(_Hit(m.start, m.end, cr.rule.resolveCommand(m)));
      }
    }
    if (hits.isEmpty) return line;

    hits.sort((a, b) => a.start.compareTo(b.start));
    final accepted = <_Hit>[];
    int cursor = 0;
    for (final h in hits) {
      if (h.start < cursor) continue;
      if (h.command.isEmpty) continue;
      accepted.add(h);
      cursor = h.end;
    }
    if (accepted.isEmpty) return line;

    return _rebuildLine(line, accepted);
  }

  /// Walks the existing spans and splits them at each accepted hit's
  /// boundaries, replacing the matched substring with a command-bearing
  /// span. Style attributes of the source span are preserved so the link
  /// "lives inside" any surrounding ANSI styling.
  StyledLine _rebuildLine(StyledLine line, List<_Hit> hits) {
    final out = <StyledSpan>[];
    int hitIdx = 0;
    int offset = 0;
    for (final span in line.spans) {
      // Existing URL/command-link spans are passed through untouched —
      // user-configured rules don't override built-in URL detection.
      if (span.link != null || span.command != null) {
        out.add(span);
        offset += span.text.length;
        continue;
      }

      final spanStart = offset;
      final spanEnd = offset + span.text.length;
      int localCursor = 0;

      while (hitIdx < hits.length && hits[hitIdx].end <= spanStart) {
        hitIdx++;
      }

      while (hitIdx < hits.length && hits[hitIdx].start < spanEnd) {
        final hit = hits[hitIdx];
        final hitStartInSpan =
            (hit.start - spanStart).clamp(0, span.text.length);
        final hitEndInSpan =
            (hit.end - spanStart).clamp(0, span.text.length);

        if (hitStartInSpan > localCursor) {
          out.add(_clone(span,
              span.text.substring(localCursor, hitStartInSpan)));
        }
        out.add(_clone(
          span,
          span.text.substring(hitStartInSpan, hitEndInSpan),
          command: hit.command,
        ));
        localCursor = hitEndInSpan;

        // If the hit extends past this span, leave it queued so the
        // remainder is consumed on the next iteration.
        if (hit.end > spanEnd) break;
        hitIdx++;
      }

      if (localCursor < span.text.length) {
        out.add(_clone(span, span.text.substring(localCursor)));
      }

      offset = spanEnd;
    }
    return StyledLine(out);
  }

  StyledSpan _clone(StyledSpan src, String text, {String? command}) {
    return StyledSpan(
      text: text,
      foreground: src.foreground,
      background: src.background,
      bold: src.bold,
      italic: src.italic,
      underline: src.underline,
      strikethrough: src.strikethrough,
      link: src.link,
      command: command ?? src.command,
    );
  }
}

class _CompiledRule {
  final TextLinkRule rule;
  final RegExp regex;
  _CompiledRule(this.rule, this.regex);
}

class _Hit {
  final int start;
  final int end;
  final String command;
  _Hit(this.start, this.end, this.command);
}
