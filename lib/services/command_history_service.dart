import 'package:flutter/foundation.dart' show debugPrint;

import 'storage/storage_service.dart';

/// Persists command history to a plain-text file (one command per line).
///
/// File location: `Command History.md` (resolved by [StorageService]).
class CommandHistoryService {
  static const _fileName = 'Command History.md';

  /// Loads history from disk, returning commands newest-first.
  ///
  /// Returns at most [maxEntries] commands. Returns an empty list on error.
  static Future<List<String>> loadHistory(
    StorageService storage, {
    int maxEntries = 500,
  }) async {
    try {
      final lines = await storage.readFileLines(_fileName);
      // File stores oldest-first (append order). Reverse for newest-first.
      final commands = lines.where((l) => l.isNotEmpty).toList().reversed.toList();
      if (commands.length > maxEntries) {
        return commands.sublist(0, maxEntries);
      }
      return commands;
    } catch (e) {
      debugPrint('CommandHistoryService.loadHistory: $e');
      return [];
    }
  }

  /// Appends a single command to the history file.
  static Future<void> appendCommand(
    StorageService storage,
    String command,
  ) async {
    try {
      await storage.appendToFile(_fileName, '$command\n');
    } catch (e) {
      debugPrint('CommandHistoryService.appendCommand: $e');
    }
  }
}
