import '../../protocol/ansi/styled_span.dart';

/// Replaces text emoticon sequences with Unicode emoji in styled output.
///
/// Operates on individual [StyledSpan] text segments, preserving all ANSI
/// styling attributes. Emoticons that span across styled spans (e.g., `:`
/// in one color and `)` in another) are not handled.
class EmojiParser {
  EmojiParser._();

  /// Map of text emoticon → Unicode emoji.
  static const Map<String, String> emoticonMap = {
    // Multi-char prefix emoticons (must match before shorter variants).
    '>:-(': '\u{1F620}', // 😠 angry
    '>:-)': '\u{1F608}', // 😈 devil grin
    '>:(': '\u{1F620}', // 😠 angry
    '>:)': '\u{1F608}', // 😈 devil grin

    // Nose variants.
    ':-)': '\u{1F642}', // 🙂 smile
    ':-(': '\u{1F641}', // 🙁 frown
    ':-D': '\u{1F600}', // 😀 grin
    ';-)': '\u{1F609}', // 😉 wink
    ':-P': '\u{1F61B}', // 😛 tongue
    ':-p': '\u{1F61B}', // 😛 tongue
    ':-O': '\u{1F62E}', // 😮 open mouth
    ':-o': '\u{1F62F}', // 😯 hushed
    ':-/': '\u{1F615}', // 😕 confused
    ':-\\': '\u{1F615}', // 😕 confused
    ':-|': '\u{1F610}', // 😐 neutral
    ':-S': '\u{1F616}', // 😖 confounded
    ':-*': '\u{1F618}', // 😘 kiss

    // Simple emoticons.
    ':)': '\u{1F642}', // 🙂 smile
    ':(': '\u{1F641}', // 🙁 frown
    ':D': '\u{1F600}', // 😀 grin
    ';)': '\u{1F609}', // 😉 wink
    ':P': '\u{1F61B}', // 😛 tongue
    ':p': '\u{1F61B}', // 😛 tongue
    ':O': '\u{1F62E}', // 😮 open mouth
    ':o': '\u{1F62F}', // 😯 hushed
    ':/': '\u{1F615}', // 😕 confused
    ':\\': '\u{1F615}', // 😕 confused
    ':|': '\u{1F610}', // 😐 neutral
    ':S': '\u{1F616}', // 😖 confounded
    ':*': '\u{1F618}', // 😘 kiss

    // Tears / special prefix.
    ":'(": '\u{1F622}', // 😢 cry

    // Sunglasses.
    'B-)': '\u{1F60E}', // 😎 cool
    'B)': '\u{1F60E}', // 😎 cool

    // Angel / halo.
    'O:)': '\u{1F607}', // 😇 angel
    '0:)': '\u{1F607}', // 😇 angel

    // Laughing.
    'XD': '\u{1F606}', // 😆 squinting laugh
    'xD': '\u{1F606}', // 😆 squinting laugh

    // Hearts.
    '</3': '\u{1F494}', // 💔 broken heart
    '<3': '\u{2764}\u{FE0F}', // ❤️ red heart

    // Kaomoji-style.
    '^_^': '\u{1F60A}', // 😊 happy
    '^^': '\u{1F60A}', // 😊 happy
    '-_-': '\u{1F611}', // 😑 expressionless
    'T_T': '\u{1F62D}', // 😭 loudly crying
    'o_O': '\u{1F928}', // 🤨 raised eyebrow
    'O_o': '\u{1F928}', // 🤨 raised eyebrow
    'o_o': '\u{1F633}', // 😳 flushed

    // Gestures / symbols.
    r'\m/': '\u{1F918}', // 🤘 metal horns
    '(y)': '\u{1F44D}', // 👍 thumbs up
  };

  /// Pre-compiled regex matching all known emoticon patterns.
  static final RegExp _regex = _buildRegex();

  /// Reverse map: Unicode emoji → shortest text emoticon.
  static final Map<String, String> _reverseMap = _buildReverseMap();

  /// Pre-compiled regex matching all known emoji for reverse parsing.
  static final RegExp _reverseRegex = _buildReverseRegex();

  /// Processes a [StyledLine], replacing emoticons in each span's text.
  /// Returns the original line if no replacements were made.
  static StyledLine processLine(StyledLine line) {
    var changed = false;
    final newSpans = <StyledSpan>[];

    for (final span in line.spans) {
      final replaced = replaceEmoticons(span.text);
      if (identical(replaced, span.text)) {
        newSpans.add(span);
      } else {
        changed = true;
        newSpans.add(StyledSpan(
          text: replaced,
          foreground: span.foreground,
          background: span.background,
          bold: span.bold,
          italic: span.italic,
          underline: span.underline,
          strikethrough: span.strikethrough,
        ));
      }
    }

    return changed ? StyledLine(newSpans) : line;
  }

  /// Regex to detect URL regions that should be protected from replacement.
  static final RegExp _urlPattern = RegExp(r'https?://[^\s]+');

  /// Replaces emoticons in a single text string.
  /// Returns the original string instance if no replacements were made.
  /// URLs are preserved — emoticon patterns inside URLs are not replaced.
  static String replaceEmoticons(String text) {
    if (text.isEmpty) return text;

    // Find URL regions to protect.
    final urlRanges = _urlPattern
        .allMatches(text)
        .map((m) => (start: m.start, end: m.end))
        .toList();

    if (urlRanges.isEmpty) {
      // Fast path: no URLs, use simple replacement.
      final result = text.replaceAllMapped(_regex, (match) {
        return emoticonMap[match.group(0)!] ?? match.group(0)!;
      });
      return result == text ? text : result;
    }

    // Slow path: skip emoticon matches that overlap any URL region.
    final result = text.replaceAllMapped(_regex, (match) {
      for (final range in urlRanges) {
        if (match.start >= range.start && match.start < range.end) {
          return match.group(0)!; // Inside a URL — keep as-is.
        }
      }
      return emoticonMap[match.group(0)!] ?? match.group(0)!;
    });
    return result == text ? text : result;
  }

  /// Replaces Unicode emoji with text emoticons for sending to the MUD.
  /// Returns the original string instance if no replacements were made.
  static String reverseEmojis(String text) {
    if (text.isEmpty) return text;
    final result = text.replaceAllMapped(_reverseRegex, (match) {
      return _reverseMap[match.group(0)!] ?? match.group(0)!;
    });
    return result == text ? text : result;
  }

  /// Builds a regex from all emoticon keys, sorted longest-first.
  static RegExp _buildRegex() {
    final keys = emoticonMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = keys.map(RegExp.escape).join('|');
    return RegExp(pattern);
  }

  /// Builds the reverse map from emoji → shortest emoticon.
  static Map<String, String> _buildReverseMap() {
    final reverse = <String, String>{};
    for (final entry in emoticonMap.entries) {
      final emoji = entry.value;
      final emoticon = entry.key;
      if (!reverse.containsKey(emoji) ||
          emoticon.length < reverse[emoji]!.length) {
        reverse[emoji] = emoticon;
      }
    }
    // Also map bare red heart (without variation selector U+FE0F).
    const heartWithVS = '\u{2764}\u{FE0F}';
    const heartBare = '\u{2764}';
    if (reverse.containsKey(heartWithVS) && !reverse.containsKey(heartBare)) {
      reverse[heartBare] = reverse[heartWithVS]!;
    }
    return reverse;
  }

  /// Builds a regex from reverse map keys (emoji), sorted longest-first.
  static RegExp _buildReverseRegex() {
    final keys = _reverseMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = keys.map(RegExp.escape).join('|');
    return RegExp(pattern);
  }
}
