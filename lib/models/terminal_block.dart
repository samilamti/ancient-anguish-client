import '../protocol/ansi/styled_span.dart';

/// Why a block boundary was created.
enum BlockBoundaryReason {
  /// Lines before any explicit boundary signal.
  initial,

  /// A prompt was detected (end of server response).
  prompt,

  /// The user sent a command.
  userCommand,

  /// Timeout: no new output for >1 second.
  timeout,
}

/// A group of consecutive terminal output lines.
class TerminalBlock {
  final int id;
  final int startLineIndex;
  final List<StyledLine> lines;
  final BlockBoundaryReason reason;

  const TerminalBlock({
    required this.id,
    required this.startLineIndex,
    required this.lines,
    required this.reason,
  });

  String get plainText => lines.map((l) => l.plainText).join('\n');
  bool get isEmpty => lines.isEmpty;
  int get lineCount => lines.length;
}
