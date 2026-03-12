import '../protocol/ansi/styled_span.dart';

/// The type of social message.
enum SocialMessageType { chat, tellIncoming, tellOutgoing }

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
  SocialMessage withContinuation(StyledLine styledLine, String plainText) {
    return SocialMessage(
      type: type,
      sender: sender,
      body: '$body\n$plainText',
      styledLines: [...styledLines, styledLine],
      timestamp: timestamp,
    );
  }
}
