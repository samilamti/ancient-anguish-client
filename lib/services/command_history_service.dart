import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

/// Persists command history to a plain-text file (one command per line).
///
/// File location: `{appDocuments}/AncientAnguishClient/Command History.md`
class CommandHistoryService {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/AncientAnguishClient/Command History.md');
  }

  /// Loads history from disk, returning commands newest-first.
  ///
  /// Returns at most [maxEntries] commands. Returns an empty list on error.
  static Future<List<String>> loadHistory({int maxEntries = 500}) async {
    try {
      final file = await _file();
      if (!file.existsSync()) return [];
      final lines = await file.readAsLines();
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
  static Future<void> appendCommand(String command) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString('$command\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('CommandHistoryService.appendCommand: $e');
    }
  }
}
