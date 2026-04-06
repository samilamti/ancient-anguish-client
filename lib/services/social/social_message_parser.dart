/// Pure-logic service for detecting and classifying social messages
/// from MUD output. No Flutter dependencies — easily testable.
class SocialMessageParser {
  // Chat patterns: "[Chat] Name: message" or "[Chat] Name emotes."
  static final RegExp _chatSayRegex =
      RegExp(r'^\[Chat\]\s+(\w+):\s+(.+)$');
  static final RegExp _chatEmoteRegex =
      RegExp(r'^\[Chat\]\s+(\w+)\s+(.+)$');

  // Party patterns: "<Party Name> Character : message" or "<Party Name> Character emotes."
  static final RegExp _partySayRegex =
      RegExp(r'^<([^>]+)>\s+(\w+)\s+:\s+(.+)$');
  static final RegExp _partyEmoteRegex =
      RegExp(r'^<([^>]+)>\s+(\w+)\s+(.+)$');

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

  /// Checks if a plain text line is a party message start.
  static PartyMatchResult? matchPartyLine(String plainText) {
    // Try "say" pattern first (has colon separator).
    final sayMatch = _partySayRegex.firstMatch(plainText);
    if (sayMatch != null) {
      return PartyMatchResult(
        partyName: sayMatch.group(1)!,
        sender: sayMatch.group(2)!,
        text: sayMatch.group(3)!,
        isEmote: false,
      );
    }

    // Try emote pattern (no colon).
    final emoteMatch = _partyEmoteRegex.firstMatch(plainText);
    if (emoteMatch != null) {
      return PartyMatchResult(
        partyName: emoteMatch.group(1)!,
        sender: emoteMatch.group(2)!,
        text: emoteMatch.group(3)!,
        isEmote: true,
      );
    }

    return null;
  }

  /// Returns true if a party match is a system message (not a player message).
  /// e.g. `<PartyName> Your party just killed the giant troll.`
  static bool isPartySystemMessage(PartyMatchResult match) {
    return match.sender == 'Your' &&
        match.text.startsWith('party just killed');
  }

  /// Returns true if a chat match is a system/NPC message (not a player message).
  /// e.g. "[Chat] The High Priest: blesses the faithful"
  /// e.g. "[Chat] Foo begins exploring."
  static bool isChatSystemMessage(ChatMatchResult match) {
    if (match.sender == 'The') return true;
    if (match.text == 'begins exploring.') return true;
    if (match.text == 'leaves to explore elsewhere.') return true;
    return false;
  }

  /// NPC senders whose tells should stay in the main terminal window.
  static const _npcTellSenders = {'Priest'};

  /// Returns true if a tell match is from an NPC (not a player).
  /// e.g. "Priest tells you: The High Priest blesses you."
  static bool isTellNpc(TellMatchResult match) {
    return _npcTellSenders.contains(match.sender);
  }

  /// Checks if a plain text line is a continuation (7+ leading spaces).
  static bool isContinuation(String plainText) {
    return _continuationRegex.hasMatch(plainText);
  }
}

/// Result from matching a party line.
class PartyMatchResult {
  final String partyName;
  final String sender;
  final String text;
  final bool isEmote;

  const PartyMatchResult({
    required this.partyName,
    required this.sender,
    required this.text,
    required this.isEmote,
  });
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
