import '../protocol/ansi/styled_span.dart';

/// The type of social message.
enum SocialMessageType { chat, tellIncoming, tellOutgoing, party }

/// A single social message parsed from MUD output.
class SocialMessage {
  final SocialMessageType type;
  final String sender;
  final String body;
  final List<StyledLine> styledLines;
  final DateTime timestamp;

  const SocialMessage({
    required this.type,
    required this.sender,
    required this.body,
    required this.styledLines,
    required this.timestamp,
  });

  /// Creates a copy with continuation text appended.
  ///
  /// MUD continuation lines arrive with 7+ leading spaces so they line up
  /// with the sender prefix in the terminal. The SWC re-flows text into
  /// panel-width rows, so that column padding renders as a large left gutter
  /// on each wrapped line. Strip the leading whitespace, and collapse any
  /// remaining runs of 2+ spaces to a single space, before appending.
  SocialMessage withContinuation(StyledLine styledLine, String plainText) {
    return SocialMessage(
      type: type,
      sender: sender,
      body: '$body\n${_collapseWhitespace(plainText)}',
      styledLines: [...styledLines, _collapseStyledWhitespace(styledLine)],
      timestamp: timestamp,
    );
  }

  static final RegExp _multiSpace = RegExp(r' {2,}');

  static String _collapseWhitespace(String s) =>
      s.trimLeft().replaceAll(_multiSpace, ' ');

  static StyledLine _collapseStyledWhitespace(StyledLine line) {
    final newSpans = <StyledSpan>[];
    var sawNonSpace = false;
    var prevWasSpace = false;
    for (final span in line.spans) {
      final buf = StringBuffer();
      for (var i = 0; i < span.text.length; i++) {
        final ch = span.text.codeUnitAt(i);
        final isSpace = ch == 0x20 || ch == 0x09; // space or tab
        if (isSpace) {
          if (!sawNonSpace || prevWasSpace) continue;
          prevWasSpace = true;
          buf.writeCharCode(0x20);
        } else {
          sawNonSpace = true;
          prevWasSpace = false;
          buf.writeCharCode(ch);
        }
      }
      if (buf.isNotEmpty) {
        newSpans.add(StyledSpan(
          text: buf.toString(),
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
    return StyledLine(newSpans);
  }
}
