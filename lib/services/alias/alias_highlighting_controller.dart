import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';

/// A [TextEditingController] for the command input that paints alias
/// keywords in [aliasColor], so typing `fb` turns blue as soon as `fb` is
/// an alias.
///
/// Mirrors how [AliasEngine] matches: only the first word of each
/// `;`-separated command can trigger an alias, case-sensitively.
class AliasHighlightingController extends TextEditingController {
  AliasHighlightingController({super.text});

  static const Color aliasColor = Color(0xFF3D8BFF);

  Set<String> _keywords = const {};

  /// Keywords of the enabled aliases. Setting a different set repaints.
  set aliasKeywords(Set<String> keywords) {
    if (setEquals(keywords, _keywords)) return;
    _keywords = keywords;
    notifyListeners();
  }

  /// Character ranges in [input] that are alias keywords.
  static List<TextRange> aliasRanges(String input, Set<String> keywords) {
    if (keywords.isEmpty) return const [];
    final ranges = <TextRange>[];
    final word = RegExp(r'\S+');
    var start = 0;
    for (final segment in input.split(';')) {
      final first = word.firstMatch(segment);
      if (first != null && keywords.contains(first.group(0))) {
        ranges.add(
          TextRange(start: start + first.start, end: start + first.end),
        );
      }
      start += segment.length + 1;
    }
    return ranges;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final ranges = aliasRanges(text, _keywords);
    if (ranges.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    // Android keyboards keep the word being typed in the composing region
    // the whole time, so bailing out to the default rendering while
    // composing would hide the colour exactly when `fb` is typed. Split at
    // both the alias ranges and the composing edges, and give each piece
    // the colour, the composing underline, or both.
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : null;
    final cuts = <int>{0, text.length};
    for (final r in ranges) {
      cuts
        ..add(r.start)
        ..add(r.end);
    }
    if (composing != null) {
      cuts
        ..add(composing.start)
        ..add(composing.end);
    }
    final points = cuts.toList()..sort();

    final children = <TextSpan>[];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      if (a == b) continue;
      final isAlias = ranges.any((r) => r.start <= a && b <= r.end);
      final isComposing =
          composing != null && composing.start <= a && b <= composing.end;
      children.add(
        TextSpan(
          text: text.substring(a, b),
          style: isAlias || isComposing
              ? TextStyle(
                  color: isAlias ? aliasColor : null,
                  decoration: isComposing ? TextDecoration.underline : null,
                )
              : null,
        ),
      );
    }
    return TextSpan(style: style, children: children);
  }
}
