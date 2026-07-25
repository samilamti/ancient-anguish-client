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
  /// Duplicates are collapsed to their most recent occurrence so the list
  /// matches the in-memory move-to-top ordering. Returns at most
  /// [maxEntries] commands. Returns an empty list on error.
  static Future<List<String>> loadHistory(StorageService storage) async {
    try {
      final lines = await storage.readFileLines(_fileName);
      // File stores oldest-first (append order). Reverse for newest-first.
      final commands = <String>[];
      final seen = <String>{};
      for (final line in lines.reversed) {
        if (line.isEmpty) continue;
        if (seen.add(line)) commands.add(line);
      }
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
  ///
  /// An earlier occurrence of the same command is dropped rather than left
  /// behind, so re-running a command refreshes its recency instead of
  /// creating a duplicate — mirroring `CommandHistoryNotifier.add`.
  static Future<void> appendCommand(
    StorageService storage,
    String command,
  ) async {
    try {
      final lines = await storage.readFileLines(_fileName);
      final commands =
          lines.where((l) => l.isNotEmpty && l != command).toList();
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
