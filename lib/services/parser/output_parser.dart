import 'dart:convert';

import '../../protocol/ansi/ansi_parser.dart';
import '../../protocol/ansi/styled_span.dart';

/// Orchestrates the conversion of raw MUD output bytes into styled lines.
///
/// Pipeline: raw bytes → UTF-8 decode → split lines → ANSI parse → [StyledLine]s.
///
/// Handles partial lines (data that arrives without a trailing newline) by
/// buffering until the next newline or flush.
class OutputParser {
  final AnsiParser _ansiParser = AnsiParser();
  final StringBuffer _lineBuffer = StringBuffer();

  /// Processes raw UTF-8 bytes from the telnet data stream.
  ///
  /// Returns a list of completed [StyledLine]s. Incomplete lines (no trailing
  /// newline) are buffered and returned when the next chunk completes them.
  List<StyledLine> processBytes(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return processText(text);
  }

  /// Processes decoded text and returns completed styled lines.
  List<StyledLine> processText(String text) {
    final lines = <StyledLine>[];

    for (var i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == '\n') {
        // Complete the current line.
        final lineText = _lineBuffer.toString();
        _lineBuffer.clear();
        lines.add(_parseLine(lineText));
      } else if (char == '\r') {
        // Skip carriage returns (we handle \n as the line break).
        continue;
      } else {
        _lineBuffer.write(char);
      }
    }

    return lines;
  }

  /// Forces the current partial line to be emitted as a complete line.
  ///
  /// Useful for prompt lines that don't end with a newline (e.g., "125/125:80/80>").
  StyledLine? flush() {
    if (_lineBuffer.isEmpty) return null;
    final lineText = _lineBuffer.toString();
    _lineBuffer.clear();
    return _parseLine(lineText);
  }

  /// Whether there is buffered partial data waiting for completion.
  bool get hasPendingData => _lineBuffer.isNotEmpty;

  /// The current partial line text (for prompt detection).
  String get pendingText => _lineBuffer.toString();

  /// Resets the parser state (e.g., on reconnect).
  void reset() {
    _lineBuffer.clear();
    _ansiParser.reset();
  }

  StyledLine _parseLine(String text) {
    if (text.isEmpty) return StyledLine.empty();
    final spans = _ansiParser.parse(text);
    return StyledLine(spans);
  }
}
