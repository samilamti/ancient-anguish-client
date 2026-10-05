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
        ranges.add(TextRange(
          start: start + first.start,
          end: start + first.end,
        ));
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
    // Leave IME composition (underlined pre-edit text) to the default
    // rendering rather than fighting it.
    final composing = withComposing && value.isComposingRangeValid;
    if (ranges.isEmpty || composing) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final aliasStyle = (style ?? const TextStyle()).copyWith(color: aliasColor);
    final children = <TextSpan>[];
    var pos = 0;
    for (final r in ranges) {
      if (r.start > pos) children.add(TextSpan(text: text.substring(pos, r.start)));
      children.add(TextSpan(text: r.textInside(text), style: aliasStyle));
      pos = r.end;
    }
    if (pos < text.length) children.add(TextSpan(text: text.substring(pos)));
    return TextSpan(style: style, children: children);
  }
}
