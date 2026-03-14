import '../../protocol/ansi/styled_span.dart';

/// Detects URLs in styled terminal text and splits them into link spans.
class LinkParser {
  LinkParser._();

  static final RegExp _urlPattern = RegExp(r'https?://[^\s]+');

  /// Processes a [StyledLine], splitting any spans that contain URLs
  /// into separate link-bearing spans.
  static StyledLine processLine(StyledLine line) {
    final result = <StyledSpan>[];
    var changed = false;

    for (final span in line.spans) {
      if (span.link != null) {
        // Already a link span.
        result.add(span);
        continue;
      }

      final matches = _urlPattern.allMatches(span.text).toList();
      if (matches.isEmpty) {
        result.add(span);
        continue;
      }

      changed = true;
      var lastEnd = 0;

      for (final match in matches) {
        // Text before the URL.
        if (match.start > lastEnd) {
          result.add(StyledSpan(
            text: span.text.substring(lastEnd, match.start),
            foreground: span.foreground,
            background: span.background,
            bold: span.bold,
            italic: span.italic,
            underline: span.underline,
            strikethrough: span.strikethrough,
          ));
        }

        // The URL span.
        final url = match.group(0)!;
        result.add(StyledSpan(
          text: url,
          foreground: span.foreground,
          background: span.background,
          bold: span.bold,
          italic: span.italic,
          underline: span.underline,
          strikethrough: span.strikethrough,
          link: Uri.tryParse(url),
        ));

        lastEnd = match.end;
      }

      // Text after the last URL.
      if (lastEnd < span.text.length) {
        result.add(StyledSpan(
          text: span.text.substring(lastEnd),
          foreground: span.foreground,
          background: span.background,
          bold: span.bold,
          italic: span.italic,
          underline: span.underline,
          strikethrough: span.strikethrough,
        ));
      }
    }

    return changed ? StyledLine(result) : line;
  }
}
