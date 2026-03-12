/// Pure-logic service for detecting and classifying social messages
/// from MUD output. No Flutter dependencies — easily testable.
class SocialMessageParser {
  // Chat patterns: "[Chat] Name: message" or "[Chat] Name emotes."
  static final RegExp _chatSayRegex =
      RegExp(r'^\[Chat\]\s+(\w+):\s+(.+)$');
  static final RegExp _chatEmoteRegex =
      RegExp(r'^\[Chat\]\s+(\w+)\s+(.+)$');

  // Tell patterns: "Name tells you: message" or "You tell Name: message"
  static final RegExp _tellIncomingRegex =
      RegExp(r'^(\w+) tells you:\s+(.+)$');
  static final RegExp _tellOutgoingRegex =
      RegExp(r'^You tell (\w+):\s+(.+)$');

  // Continuation: 7+ leading spaces.
  static final RegExp _continuationRegex = RegExp(r'^(\s{7,})(\S.*)$');

  /// Checks if a plain text line is a chat message start.
  static ChatMatchResult? matchChatLine(String plainText) {
    // Try "say" pattern first (has colon).
    final sayMatch = _chatSayRegex.firstMatch(plainText);
    if (sayMatch != null) {
      return ChatMatchResult(
        sender: sayMatch.group(1)!,
        text: sayMatch.group(2)!,
        isEmote: false,
      );
    }

    // Try emote pattern (no colon).
    final emoteMatch = _chatEmoteRegex.firstMatch(plainText);
    if (emoteMatch != null) {
      return ChatMatchResult(
        sender: emoteMatch.group(1)!,
        text: emoteMatch.group(2)!,
        isEmote: true,
      );
    }

    return null;
  }

  /// Checks if a plain text line is a tell message start.
  static TellMatchResult? matchTellLine(String plainText) {
    final inMatch = _tellIncomingRegex.firstMatch(plainText);
    if (inMatch != null) {
      return TellMatchResult(
        sender: inMatch.group(1)!,
        text: inMatch.group(2)!,
        isOutgoing: false,
      );
    }

    final outMatch = _tellOutgoingRegex.firstMatch(plainText);
    if (outMatch != null) {
      return TellMatchResult(
        sender: outMatch.group(1)!,
        text: outMatch.group(2)!,
        isOutgoing: true,
      );
    }

    return null;
  }

  /// Checks if a plain text line is a continuation (7+ leading spaces).
  static bool isContinuation(String plainText) {
    return _continuationRegex.hasMatch(plainText);
  }
}

/// Result from matching a chat line.
class ChatMatchResult {
  final String sender;
  final String text;
  final bool isEmote;

  const ChatMatchResult({
    required this.sender,
    required this.text,
    required this.isEmote,
  });
}

/// Result from matching a tell line.
class TellMatchResult {
  final String sender;
  final String text;
  final bool isOutgoing;

  const TellMatchResult({
    required this.sender,
    required this.text,
    required this.isOutgoing,
  });
}
