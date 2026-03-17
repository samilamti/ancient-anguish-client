import 'package:flutter/foundation.dart' show debugPrint;

import '../../models/social_message.dart';
import '../../protocol/ansi/styled_span.dart';
import '../storage/storage_service.dart';
import 'social_message_parser.dart';

/// Persists social messages to human-readable Markdown files.
///
/// Files are stored in per-day files within subfolders:
/// - `Chat History/2026-03-17.md`
/// - `Tell History/2026-03-17.md`
///
/// File format (no date headers — date is the file name):
/// ```
/// 09:15 Gandalf: Hello everyone!
/// 09:16 Frodo: Pretty rough actually
/// ```
class SocialHistoryService {
  // Write queues serialize disk I/O per file so that continuation lines
  // are always written after the initial message completes.
  static Future<void> _chatQueue = Future.value();
  static Future<void> _tellQueue = Future.value();

  static const _chatFolder = 'Chat History';
  static const _tellFolder = 'Tell History';

  static String _filePath(bool isChat, DateTime dt) {
    final folder = isChat ? _chatFolder : _tellFolder;
    return '$folder/${_formatDate(dt)}.md';
  }

  /// Queues a message append to the appropriate history file.
  static void appendMessage(
    StorageService storage,
    SocialMessage msg, {
    required bool isChat,
  }) {
    if (isChat) {
      _chatQueue = _chatQueue.then((_) => _doAppendMessage(storage, msg, isChat: true));
    } else {
      _tellQueue = _tellQueue.then((_) => _doAppendMessage(storage, msg, isChat: false));
    }
  }

  /// Queues a continuation line append to the history file.
  static void appendContinuation(
    StorageService storage,
    String plainText, {
    required bool isChat,
  }) {
    if (isChat) {
      _chatQueue =
          _chatQueue.then((_) => _doAppendContinuation(storage, plainText, isChat: true));
    } else {
      _tellQueue =
          _tellQueue.then((_) => _doAppendContinuation(storage, plainText, isChat: false));
    }
  }

  static Future<void> _doAppendMessage(
    StorageService storage,
    SocialMessage msg, {
    required bool isChat,
  }) async {
    try {
      final fileName = _filePath(isChat, msg.timestamp);
      final timeStr = _formatTime(msg.timestamp);

      // Format the message body.
      final body = isChat ? _stripChatPrefix(msg.body) : msg.body;
      // Handle multi-line bodies (continuations).
      final lines = body.split('\n');
      final buffer = StringBuffer();
      buffer.writeln('$timeStr ${lines.first}');
      for (var i = 1; i < lines.length; i++) {
        buffer.writeln(lines[i]);
      }

      await storage.appendToFile(fileName, buffer.toString());
    } catch (e) {
      debugPrint('SocialHistoryService._doAppendMessage: $e');
    }
  }

  static Future<void> _doAppendContinuation(
    StorageService storage,
    String plainText, {
    required bool isChat,
  }) async {
    try {
      final fileName = _filePath(isChat, DateTime.now());
      await storage.appendToFile(fileName, '$plainText\n');
    } catch (e) {
      debugPrint('SocialHistoryService._doAppendContinuation: $e');
    }
  }

  /// Loads chat messages from disk for today.
  static Future<List<SocialMessage>> loadChat(StorageService storage) async {
    return _loadFile(storage, isChat: true, date: _formatDate(DateTime.now()));
  }

  /// Loads tell messages from disk for today.
  static Future<List<SocialMessage>> loadTells(StorageService storage) async {
    return _loadFile(storage, isChat: false, date: _formatDate(DateTime.now()));
  }

  static Future<List<SocialMessage>> _loadFile(
    StorageService storage, {
    required bool isChat,
    required String date,
  }) async {
    try {
      final folder = isChat ? _chatFolder : _tellFolder;
      final fileName = '$folder/$date.md';
      final contents = await storage.readFile(fileName);
      if (contents.trim().isEmpty) return [];
      return _parseHistory(contents, date: date, isChat: isChat);
    } catch (e) {
      debugPrint('SocialHistoryService._loadFile: $e');
      return [];
    }
  }

  /// Parses a per-day history file into SocialMessage objects.
  static List<SocialMessage> _parseHistory(
    String contents, {
    required String date,
    required bool isChat,
  }) {
    final messages = <SocialMessage>[];
    final lines = contents.split('\n');
    SocialMessage? pending;

    for (final line in lines) {
      // Skip empty lines.
      if (line.trim().isEmpty) {
        if (pending != null) messages.add(pending);
        pending = null;
        continue;
      }

      // Timestamped entry: "HH:mm text"
      final entryMatch = _entryRegex.firstMatch(line);
      if (entryMatch != null) {
        if (pending != null) messages.add(pending);

        final timeStr = entryMatch.group(1)!;
        final text = entryMatch.group(2)!;
        final timestamp = _parseDateTime(date, timeStr);

        pending = _createMessage(text, timestamp, isChat: isChat);
        continue;
      }

      // Continuation line (no timestamp prefix) — append to pending.
      if (pending != null) {
        final styledLine = StyledLine([StyledSpan(text: line)]);
        pending = pending.withContinuation(styledLine, line);
      }
    }

    if (pending != null) messages.add(pending);
    return messages;
  }

  static SocialMessage _createMessage(
    String text,
    DateTime timestamp, {
    required bool isChat,
  }) {
    if (isChat) {
      // Reconstruct original MUD line for parsing.
      // Stored format: "Gandalf: Hello" or "Gandalf emotes."
      // We need to try matching as chat to get sender info.
      final chatMatch =
          SocialMessageParser.matchChatLine('[Chat] $text');
      final sender = chatMatch?.sender ?? 'unknown';
      return SocialMessage(
        type: SocialMessageType.chat,
        sender: sender,
        body: '[Chat] $text',
        styledLines: [StyledLine([StyledSpan(text: '[Chat] $text')])],
        timestamp: timestamp,
      );
    } else {
      // Tell format preserved: "Gandalf tells you: hello" or "You tell Gandalf: hi"
      final tellMatch = SocialMessageParser.matchTellLine(text);
      final type = tellMatch != null && tellMatch.isOutgoing
          ? SocialMessageType.tellOutgoing
          : SocialMessageType.tellIncoming;
      final sender = tellMatch?.sender ?? 'unknown';
      return SocialMessage(
        type: type,
        sender: sender,
        body: text,
        styledLines: [StyledLine([StyledSpan(text: text)])],
        timestamp: timestamp,
      );
    }
  }

  static String _stripChatPrefix(String body) {
    // Remove "[Chat] " prefix from each line that has it.
    return body.replaceAll(RegExp(r'^\[Chat\]\s+', multiLine: true), '');
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static DateTime _parseDateTime(String date, String time) {
    try {
      return DateTime.parse('${date}T$time:00');
    } catch (_) {
      return DateTime.now();
    }
  }

  static final RegExp _entryRegex = RegExp(r'^(\d{2}:\d{2}) (.+)$');
}
