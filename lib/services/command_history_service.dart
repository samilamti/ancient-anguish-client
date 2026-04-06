import 'package:flutter/foundation.dart' show debugPrint;

import 'storage/storage_service.dart';

/// Persists command history to a plain-text file (one command per line).
///
/// File location: `Command History.md` (resolved by [StorageService]).
/// Maintains a maximum of [maxEntries] commands on disk.
class CommandHistoryService {
  static const _fileName = 'Command History.md';
  static const int maxEntries = 20;

  /// Loads history from disk, returning commands newest-first.
  ///
  /// Returns at most [maxEntries] commands. Returns an empty list on error.
  static Future<List<String>> loadHistory(StorageService storage) async {
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

  /// Appends a single command to the history file, enforcing the max entry cap.
  static Future<void> appendCommand(
    StorageService storage,
    String command,
  ) async {
    try {
      final lines = await storage.readFileLines(_fileName);
      final commands = lines.where((l) => l.isNotEmpty).toList();
      commands.add(command);

      // Keep only the most recent entries.
      final trimmed = commands.length > maxEntries
          ? commands.sublist(commands.length - maxEntries)
          : commands;

      await storage.writeFile(_fileName, '${trimmed.join('\n')}\n');
    } catch (e) {
      debugPrint('CommandHistoryService.appendCommand: $e');
    }
  }
}
