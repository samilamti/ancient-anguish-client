import '../protocol/ansi/styled_span.dart';

/// A block of MUD output framed by `+---+` borders that isn't a map —
/// typically a shop listing, info card, or anything else the MUD draws
/// inside an ASCII frame. Rendered by the terminal view as a parchment
/// card widget; the original frame characters (`+---+` and edge `|`)
/// are stripped before construction so the widget owns its own frame.
class FramedTextBlock {
  final List<StyledLine> lines;

  const FramedTextBlock(this.lines);

  int get lineCount => lines.length;
}

/// Strips the leading `|` and trailing `|` from a content row so the
/// parchment widget can render just the interior text. Returns the line
/// unchanged if it doesn't look like a framed content row.
StyledLine stripFramedRowEdges(StyledLine line) {
  final text = line.plainText;
  final trimmedRight = text.trimRight();
  if (!trimmedRight.startsWith('|') || !trimmedRight.endsWith('|')) {
    return line;
  }
  // Trim trailing whitespace first (so the `|` we remove is the real edge,
  // not a stray pipe mid-line), then drop one leading char and one trailing
  // char. Using removeRange preserves styling on the interior spans.
  final trailingWs = text.length - trimmedRight.length;
  final afterTrailingStrip = trailingWs > 0
      ? line.removeRange(trimmedRight.length, text.length)
      : line;
  // Remove the trailing `|`.
  final withoutTrailingPipe = afterTrailingStrip.removeRange(
    trimmedRight.length - 1,
    trimmedRight.length,
  );
  // Remove the leading `|`.
  return withoutTrailingPipe.removeRange(0, 1);
}
