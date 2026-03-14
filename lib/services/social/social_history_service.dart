import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import '../../models/social_message.dart';
import '../../protocol/ansi/styled_span.dart';
import 'social_message_parser.dart';

/// Persists social messages to human-readable Markdown files.
///
/// File format:
/// ```
/// # 2026-03-14
///
/// 09:15 Gandalf: Hello everyone!
/// 09:16 Frodo: Pretty rough actually
/// ```
class SocialHistoryService {
  static Future<String> _dir() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/AncientAnguishClient';
  }

  static Future<File> _chatFile() async =>
      File('${await _dir()}/Chat History.md');

  static Future<File> _tellFile() async =>
      File('${await _dir()}/Tell History.md');

  /// Appends a message to the appropriate history file.
  static Future<void> appendMessage(
    SocialMessage msg, {
    required bool isChat,
  }) async {
    try {
      final file = isChat ? await _chatFile() : await _tellFile();
      await file.parent.create(recursive: true);

      final dateStr = _formatDate(msg.timestamp);
      final timeStr = _formatTime(msg.timestamp);

      final sink = file.openWrite(mode: FileMode.append);
      try {
        // Check if we need a new date header.
        final needsHeader = await _needsDateHeader(file, dateStr);
        if (needsHeader) {
          // Add blank line before header (unless file is empty).
          final length = await file.length();
          if (length > 0) sink.write('\n');
          sink.writeln('# $dateStr');
          sink.writeln();
        }

        // Format the message body.
        final body = isChat ? _stripChatPrefix(msg.body) : msg.body;
        // Handle multi-line bodies (continuations).
        final lines = body.split('\n');
        sink.writeln('$timeStr ${lines.first}');
        for (var i = 1; i < lines.length; i++) {
          sink.writeln(lines[i]);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    } catch (e) {
      debugPrint('SocialHistoryService.appendMessage: $e');
    }
  }

  /// Appends a continuation line to the history file.
  static Future<void> appendContinuation(
    String plainText, {
    required bool isChat,
  }) async {
    try {
      final file = isChat ? await _chatFile() : await _tellFile();
      if (!file.existsSync()) return;
      await file.writeAsString('$plainText\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('SocialHistoryService.appendContinuation: $e');
    }
  }

  /// Loads chat messages from disk.
  static Future<List<SocialMessage>> loadChat() async {
    return _loadFile(await _chatFile(), isChat: true);
  }

  /// Loads tell messages from disk.
  static Future<List<SocialMessage>> loadTells() async {
    return _loadFile(await _tellFile(), isChat: false);
  }

  static Future<List<SocialMessage>> _loadFile(
    File file, {
    required bool isChat,
  }) async {
    try {
      if (!file.existsSync()) return [];
      final contents = await file.readAsString();
      if (contents.trim().isEmpty) return [];
      return _parseHistory(contents, isChat: isChat);
    } catch (e) {
      debugPrint('SocialHistoryService._loadFile: $e');
      return [];
    }
  }

  /// Parses a history Markdown file into SocialMessage objects.
  static List<SocialMessage> _parseHistory(
    String contents, {
    required bool isChat,
  }) {
    final messages = <SocialMessage>[];
    final lines = contents.split('\n');
    String? currentDate;
    SocialMessage? pending;

    for (final line in lines) {
      // Date header: "# YYYY-MM-DD"
      final dateMatch = _dateHeaderRegex.firstMatch(line);
      if (dateMatch != null) {
        if (pending != null) messages.add(pending);
        pending = null;
        currentDate = dateMatch.group(1);
        continue;
      }

      // Skip empty lines.
      if (line.trim().isEmpty) {
        if (pending != null) messages.add(pending);
        pending = null;
        continue;
      }

      // Timestamped entry: "HH:mm text"
      final entryMatch = _entryRegex.firstMatch(line);
      if (entryMatch != null && currentDate != null) {
        if (pending != null) messages.add(pending);

        final timeStr = entryMatch.group(1)!;
        final text = entryMatch.group(2)!;
        final timestamp = _parseDateTime(currentDate, timeStr);

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

  static Future<bool> _needsDateHeader(File file, String dateStr) async {
    if (!file.existsSync()) return true;
    final length = await file.length();
    if (length == 0) return true;

    // Read the last portion of the file to find the most recent date header.
    final contents = await file.readAsString();
    final matches = _dateHeaderRegex.allMatches(contents);
    if (matches.isEmpty) return true;
    return matches.last.group(1) != dateStr;
  }

  static final RegExp _dateHeaderRegex = RegExp(r'^# (\d{4}-\d{2}-\d{2})$',
      multiLine: true);
  static final RegExp _entryRegex = RegExp(r'^(\d{2}:\d{2}) (.+)$');
}
