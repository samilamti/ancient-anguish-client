import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for logging MUD session output to disk.
///
/// Writes plain-text (ANSI-stripped) session logs to timestamped files
/// in the app's documents directory under a `logs/` subfolder.
class LogService {
  IOSink? _sink;
  String? _currentLogPath;
  bool _enabled = false;

  /// Whether logging is currently active.
  bool get isEnabled => _enabled;

  /// The path to the current log file, if any.
  String? get currentLogPath => _currentLogPath;

  /// Starts logging to a new timestamped file.
  Future<void> startLogging() async {
    if (_enabled) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/AncientAnguishClient/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final logFile = File('${logDir.path}/session_$timestamp.txt');

      _sink = logFile.openWrite(mode: FileMode.append);
      _currentLogPath = logFile.path;
      _enabled = true;

      _sink!.writeln('=== Session started: ${DateTime.now()} ===');
      _sink!.writeln();
    } catch (e) {
      debugPrint('LogService.startLogging error: $e');
      _enabled = false;
      _sink = null;
    }
  }

  /// Logs a line of plain text (ANSI codes should be stripped before calling).
  void logLine(String plainText) {
    if (!_enabled || _sink == null) return;
    _sink!.writeln(plainText);
  }

  /// Logs a system message (connection events, etc.).
  void logSystem(String message) {
    if (!_enabled || _sink == null) return;
    _sink!.writeln('*** $message');
  }

  /// Stops logging and closes the file.
  Future<void> stopLogging() async {
    if (!_enabled) return;

    _sink?.writeln();
    _sink?.writeln('=== Session ended: ${DateTime.now()} ===');
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _enabled = false;
  }

  /// Disposes of all resources.
  Future<void> dispose() async {
    await stopLogging();
  }
}
