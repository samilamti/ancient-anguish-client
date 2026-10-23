import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement.dart';
import '../services/storage/storage_service.dart';
import 'storage_provider.dart';

/// Achievements captured from the MUD, oldest first, persisted to
/// `Achievements.json`.
final achievementsProvider =
    NotifierProvider<AchievementsNotifier, List<Achievement>>(
        AchievementsNotifier.new);

class AchievementsNotifier extends Notifier<List<Achievement>> {
  static const _fileName = 'Achievements.json';
  static const int _maxEntries = 1000;

  StorageService get _storage => ref.read(storageServiceProvider);

  /// Serialises writes so two achievements arriving in one batch can't
  /// finish their disk writes out of order.
  Future<void> _writeQueue = Future.value();

  /// Writes wait for the initial read: saving earlier would put the
  /// pre-load additions on disk, and the read would then merge them twice.
  bool _loaded = false;

  @override
  List<Achievement> build() {
    Future.microtask(_loadFromDisk);
    return const [];
  }

  Future<void> _loadFromDisk() async {
    try {
      final raw = await _storage.readFile(_fileName);
      final decoded = raw.trim().isEmpty ? null : jsonDecode(raw);
      if (decoded is List) {
        final loaded = decoded
            .map(Achievement.fromJson)
            .whereType<Achievement>()
            .toList();
        // Keep anything captured before the load finished, rather than
        // letting the slower disk read clobber it.
        state = _cap([...loaded, ...state]);
      }
      _loaded = true;
      if (state.isNotEmpty) _save();
    } catch (e) {
      // Leave _loaded false: writing now would replace a file we couldn't
      // read with only this session's entries.
      debugPrint('AchievementsNotifier._loadFromDisk: $e');
    }
  }

  void add(Achievement achievement) {
    state = _cap([...state, achievement]);
    _save();
  }

  void clear() {
    state = const [];
    _save();
  }

  List<Achievement> _cap(List<Achievement> list) => list.length > _maxEntries
      ? list.sublist(list.length - _maxEntries)
      : list;

  void _save() {
    if (!_loaded) return;
    final snapshot = jsonEncode(state.map((a) => a.toJson()).toList());
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _storage.writeFile(_fileName, snapshot);
      } catch (e) {
        debugPrint('AchievementsNotifier._save: $e');
      }
    });
  }
}
