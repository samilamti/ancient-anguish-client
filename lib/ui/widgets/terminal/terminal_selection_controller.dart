import 'package:flutter/services.dart';

import '../../../protocol/ansi/styled_span.dart';
import 'terminal_selection.dart';

/// Manages text selection state and clipboard operations for the terminal.
///
/// Tracks selection as a pair of [TerminalPosition]s (anchor + focus) and
/// provides methods to start, update, clear, and copy the selection.
class TerminalSelectionController {
  TerminalSelection? _selection;

  /// The current selection, or `null` if nothing is selected.
  TerminalSelection? get selection => _selection;

  /// Whether the terminal currently has selected text.
  bool get hasSelection => _selection != null;

  /// Begins a new selection at [position].
  ///
  /// Returns `true` if state changed (caller should rebuild).
  bool startSelection(TerminalPosition position) {
    final sel = TerminalSelection(anchor: position, focus: position);
    if (_selection == sel) return false;
    _selection = sel;
    return true;
  }

  /// Extends the current selection to [position].
  ///
  /// If no selection exists, starts a new one.
  /// Returns `true` if state changed.
  bool updateSelection(TerminalPosition position) {
    if (_selection == null) return startSelection(position);
    final sel = TerminalSelection(anchor: _selection!.anchor, focus: position);
    if (_selection == sel) return false;
    _selection = sel;
    return true;
  }

  /// Clears the selection.
  ///
  /// Returns `true` if there was a selection to clear.
  bool clearSelection() {
    if (_selection == null) return false;
    _selection = null;
    return true;
  }

  /// Selects all lines in the buffer.
  ///
  /// [lineCount] is the total number of lines.
  /// [lastLineLength] is the character count of the final line.
  bool selectAll(int lineCount, int lastLineLength) {
    if (lineCount == 0) return false;
    final sel = TerminalSelection(
      anchor: const TerminalPosition(0, 0),
      focus: TerminalPosition(lineCount - 1, lastLineLength),
    );
    if (_selection == sel) return false;
    _selection = sel;
    return true;
  }

  /// Selects an entire line.
  bool selectLine(int lineIndex, int lineLength) {
    final sel = TerminalSelection(
      anchor: TerminalPosition(lineIndex, 0),
      focus: TerminalPosition(lineIndex, lineLength),
    );
    if (_selection == sel) return false;
    _selection = sel;
    return true;
  }

  /// Copies the selected text to the system clipboard.
  ///
  /// No-op if there is no selection.
  Future<void> copyToClipboard(List<StyledLine> lines) async {
    if (_selection == null) return;
    final text = _selection!.extractText(lines);
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  /// Returns the full plain text of the terminal buffer, joined by newlines.
  String getAllText(List<StyledLine> lines) {
    return lines.map((l) => l.plainText).join('\n');
  }
}
