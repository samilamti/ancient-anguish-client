import 'package:flutter/foundation.dart';

import '../storage/storage_service.dart';

/// Service for logging MUD session output to disk.
///
/// Writes plain-text (ANSI-stripped) session logs to timestamped files
/// in the app's documents directory under a `logs/` subfolder.
class LogService {
  StorageService? _storage;
  String? _currentLogName;
  bool _enabled = false;

  // Buffer writes to avoid excessive I/O.
  final _buffer = StringBuffer();
  bool _flushing = false;

  /// Whether logging is currently active.
  bool get isEnabled => _enabled;

  /// The logical name of the current log file, if any.
  String? get currentLogName => _currentLogName;

  /// Starts logging to a new timestamped file.
  Future<void> startLogging(StorageService storage) async {
    if (_enabled) return;

    try {
      _storage = storage;
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      _currentLogName = 'logs/session_$timestamp.txt';
      _enabled = true;

      _buffer.writeln('=== Session started: ${DateTime.now()} ===');
      _buffer.writeln();
      await _flush();
    } catch (e) {
      debugPrint('LogService.startLogging error: $e');
      _enabled = false;
      _storage = null;
    }
  }

  /// Logs a line of plain text (ANSI codes should be stripped before calling).
  void logLine(String plainText) {
    if (!_enabled || _storage == null) return;
    _buffer.writeln(plainText);
    _scheduleFlush();
  }

  /// Logs a system message (connection events, etc.).
  void logSystem(String message) {
    if (!_enabled || _storage == null) return;
    _buffer.writeln('*** $message');
    _scheduleFlush();
  }

  /// Stops logging and flushes remaining buffer.
  Future<void> stopLogging() async {
    if (!_enabled) return;

    _buffer.writeln();
    _buffer.writeln('=== Session ended: ${DateTime.now()} ===');
    await _flush();
    _enabled = false;
    _currentLogName = null;
  }

  /// Disposes of all resources.
  Future<void> dispose() async {
    await stopLogging();
  }

  // ── Internal ──

  void _scheduleFlush() {
    if (_flushing) return;
    // Flush on next microtask to batch multiple logLine calls.
    Future.microtask(() => _flush());
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty || _storage == null || _currentLogName == null) return;
    _flushing = true;
    try {
      final text = _buffer.toString();
      _buffer.clear();
      await _storage!.appendToFile(_currentLogName!, text);
    } catch (e) {
      debugPrint('LogService._flush error: $e');
    } finally {
      _flushing = false;
    }
  }
}
