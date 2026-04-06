import '../../../protocol/ansi/styled_span.dart';

/// A position in the terminal buffer: line index + character offset.
class TerminalPosition implements Comparable<TerminalPosition> {
  final int line;
  final int column;

  const TerminalPosition(this.line, this.column);

  @override
  int compareTo(TerminalPosition other) {
    if (line != other.line) return line.compareTo(other.line);
    return column.compareTo(other.column);
  }

  bool operator <(TerminalPosition other) => compareTo(other) < 0;
  bool operator >(TerminalPosition other) => compareTo(other) > 0;
  bool operator <=(TerminalPosition other) => compareTo(other) <= 0;
  bool operator >=(TerminalPosition other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is TerminalPosition && line == other.line && column == other.column;

  @override
  int get hashCode => Object.hash(line, column);

  @override
  String toString() => 'TerminalPosition($line, $column)';
}

/// A text selection range in the terminal buffer.
///
/// [anchor] is where the user started dragging.
/// [focus] is where the pointer currently is (or ended).
class TerminalSelection {
  final TerminalPosition anchor;
  final TerminalPosition focus;

  const TerminalSelection({required this.anchor, required this.focus});

  /// The earlier of anchor/focus.
  TerminalPosition get start => anchor <= focus ? anchor : focus;

  /// The later of anchor/focus.
  TerminalPosition get end => anchor <= focus ? focus : anchor;

  /// Whether the given line is fully or partially within the selection.
  bool containsLine(int lineIndex) {
    return lineIndex >= start.line && lineIndex <= end.line;
  }

  /// Returns the selected character range `(startCol, endCol)` for a line.
  ///
  /// Returns `null` if the line is not in the selection.
  /// [lineLength] is the total character count of the line's plain text.
  ({int startCol, int endCol})? selectedRangeForLine(
    int lineIndex,
    int lineLength,
  ) {
    if (!containsLine(lineIndex)) return null;
    final startCol = lineIndex == start.line ? start.column : 0;
    final endCol = lineIndex == end.line ? end.column : lineLength;
    return (startCol: startCol, endCol: endCol);
  }

  /// Extracts the selected plain text from the buffer.
  String extractText(List<StyledLine> lines) {
    final buf = StringBuffer();
    for (var i = start.line; i <= end.line && i < lines.length; i++) {
      final text = lines[i].plainText;
      final range = selectedRangeForLine(i, text.length);
      if (range != null) {
        final s = range.startCol.clamp(0, text.length);
        final e = range.endCol.clamp(0, text.length);
        buf.write(text.substring(s, e));
      }
      if (i < end.line) buf.writeln();
    }
    return buf.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is TerminalSelection &&
      anchor == other.anchor &&
      focus == other.focus;

  @override
  int get hashCode => Object.hash(anchor, focus);

  @override
  String toString() => 'TerminalSelection($anchor -> $focus)';
}
