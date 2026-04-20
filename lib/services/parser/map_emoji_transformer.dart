import '../../protocol/ansi/styled_span.dart';

/// Transforms 2-character ASCII map tiles into emoji glyphs.
///
/// The MUD draws maps inside a `+---+` bordered box, with each tile encoded
/// as two characters separated by single spaces (e.g. `/\`, `oo`, `~~`). The
/// caller ([ConnectionProvider]) only invokes this when already known to be
/// inside a map block and when the user has opted in via
/// `settings.emojiMapsEnabled`.
///
/// Follows the same shape as [EmojiParser.processLine] — iterate spans,
/// transform `text`, preserve every ANSI styling attribute, return the
/// original line if nothing changed.
class MapEmojiTransformer {
  /// Player position sentinel: 🔴 + zero-width joiner. The terminal
  /// renderer detects this exact sequence and swaps in a pulsing widget so
  /// only the map player marker pulses — an accidental 🔴 in chat stays
  /// static.
  static const String playerMarker = '\u{1F534}\u200D';

  /// Base terrain tiles — high confidence (common MUD conventions).
  static const Map<String, String> kMapEmoji = {
    // Terrain
    '/\\': '🏔️',
    '^^': '🗻',
    'oo': '🌿',
    'OO': '🌲',
    '""': '🌾',
    '~~': '🌊',
    '==': '🟫',
    '::': '⚫',
    '##': '🧱',
    '[]': '🏠',
    '88': '🏚️',

    // Road overlays collapse to a single road tile so a road reads as a
    // continuous line across the map.
    '+o': '🟫',
    '+O': '🟫',
    '+^': '🟫',
    '+"': '🟫',
    '+@': '🟫',
    '+|': '🌉',

    // Landmarks / composite tiles (best-effort guesses).
    '@^': '📍',
    '@\\': '📍',
    'Y\\': '🌲',
    'Y#': '🌳',
    ':#': '🧱',
    'o#': '🧱',
    'O#': '🌳',
  };

  /// Returns true if the plain text of [line] looks like a map content row —
  /// framed by pipes (`| ... |`). Border lines (`+---+`) are skipped.
  static bool isMapContent(String plainText) {
    final trimmed = plainText.trimRight();
    if (trimmed.length < 3) return false;
    return trimmed.startsWith('|') && trimmed.endsWith('|');
  }

  /// Transforms a single styled map line. Returns [line] unchanged when the
  /// line isn't a map content row or when no tokens matched.
  static StyledLine processLine(StyledLine line) {
    if (!isMapContent(line.plainText)) return line;

    var changed = false;
    final newSpans = <StyledSpan>[];
    for (final span in line.spans) {
      final replaced = _transform(span.text);
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
          link: span.link,
        ));
      }
    }
    return changed ? StyledLine(newSpans) : line;
  }

  /// Walks a pure-ASCII span, substituting space-delimited 2-char tokens
  /// that appear in [kMapEmoji]. Also replaces the 4-char `<[]>` player
  /// marker with [playerMarker].
  static String _transform(String s) {
    if (s.isEmpty) return s;

    // Step 1: scan 2-char tokens bounded by space/pipe on both sides.
    // Spans arrive as ASCII here (we've not yet injected any emoji), so
    // 1 char == 1 UTF-16 code unit and simple indexing is safe.
    final buf = StringBuffer();
    var i = 0;
    var matched = false;
    while (i < s.length) {
      final leftBoundary = i == 0 || s[i - 1] == ' ' || s[i - 1] == '|';
      if (leftBoundary && i + 2 <= s.length) {
        final token = s.substring(i, i + 2);
        final rightBoundary =
            i + 2 == s.length || s[i + 2] == ' ' || s[i + 2] == '|';
        if (rightBoundary) {
          final emoji = kMapEmoji[token];
          if (emoji != null) {
            buf.write(emoji);
            matched = true;
            i += 2;
            continue;
          }
        }
      }
      buf.write(s[i]);
      i++;
    }

    // Step 2: player marker (a 4-char token that crosses the usual cell
    // grid, so it's replaced as a simple substring).
    var result = matched ? buf.toString() : s;
    if (result.contains('<[]>')) {
      result = result.replaceAll('<[]>', playerMarker);
      return result;
    }

    return matched ? result : s;
  }
}
