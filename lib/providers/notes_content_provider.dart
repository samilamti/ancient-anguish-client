import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage/storage_service.dart';
import 'storage_provider.dart';

/// Persisted free-form text shown in the Notes panel.
///
/// Loaded from `Notes.md` on first watch and saved back with a 500 ms debounce
/// so continuous typing doesn't hammer the disk.
final notesContentProvider =
    NotifierProvider<NotesContentNotifier, String>(NotesContentNotifier.new);

class NotesContentNotifier extends Notifier<String> {
  static const _fileName = 'Notes.md';
  static const _debounce = Duration(milliseconds: 500);

  late final StorageService _storage;
  Timer? _saveTimer;

  @override
  String build() {
    _storage = ref.read(storageServiceProvider);
    ref.onDispose(() {
      _saveTimer?.cancel();
    });
    // Fire-and-forget: load saved content from disk after first frame.
    Future.microtask(_loadFromDisk);
    return '';
  }

  Future<void> _loadFromDisk() async {
    try {
      final contents = await _storage.readFile(_fileName);
      if (contents != state) {
        state = contents;
      }
    } catch (e) {
      debugPrint('NotesContentNotifier._loadFromDisk: $e');
    }
  }

  /// Updates in-memory state immediately and schedules a debounced disk write.
  void updateContent(String text) {
    if (text == state) return;
    state = text;
    _saveTimer?.cancel();
    _saveTimer = Timer(_debounce, _saveToDisk);
  }

  /// Cancels any pending debounced save and writes the current state now.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _saveToDisk();
  }

  Future<void> _saveToDisk() async {
    try {
      await _storage.writeFile(_fileName, state);
    } catch (e) {
      debugPrint('NotesContentNotifier._saveToDisk: $e');
    }
  }
}
