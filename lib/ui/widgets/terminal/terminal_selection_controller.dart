import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart';

import '../../../protocol/ansi/styled_span.dart';

/// Manages text selection state and clipboard operations for the terminal.
///
/// Extracted from [TerminalView] state to enable unit testing of the
/// selection/copy logic independently of the widget tree.
class TerminalSelectionController {
  bool _hasSelection = false;
  SelectedContent? _lastSelectedContent;

  /// Whether the terminal currently has selected text.
  bool get hasSelection => _hasSelection;

  /// Called by [SelectionArea.onSelectionChanged].
  ///
  /// Returns `true` if [hasSelection] changed (caller should call setState).
  bool onSelectionChanged(SelectedContent? content) {
    _lastSelectedContent = content;
    final hasText = content != null && content.plainText.isNotEmpty;
    if (_hasSelection != hasText) {
      _hasSelection = hasText;
      return true;
    }
    return false;
  }

  /// Copies the current selection's plain text to the system clipboard.
  ///
  /// No-op if there is no selection or the selection is empty.
  Future<void> copySelectionToClipboard() async {
    final text = _lastSelectedContent?.plainText;
    if (text != null && text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  /// Returns the full plain text of the terminal buffer, joined by newlines.
  String getAllText(List<StyledLine> lines) {
    return lines.map((l) => l.plainText).join('\n');
  }
}
