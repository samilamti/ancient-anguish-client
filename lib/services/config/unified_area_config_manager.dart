import 'package:flutter/foundation.dart' show debugPrint;

import '../../models/area_config_entry.dart';
import '../storage/storage_service.dart';
import 'markdown_config_parser.dart';
import 'migration.dart';

/// Central manager for the unified `Area Configuration.md` file.
///
/// Owns all area-to-coordinate, area-to-background, and area-to-music mappings
/// plus battle themes. Provides mutation methods that persist to disk and
/// cycling logic for multiple entries per area.
class UnifiedAreaConfigManager {
  UnifiedAreaConfig _config = UnifiedAreaConfig.empty;

  /// In-memory cycling indices (reset on app restart).
  final Map<String, int> _backgroundCycleIndex = {};
  final Map<String, int> _musicCycleIndex = {};

  /// Whether persistence is active.
  bool _persistEnabled = false;

  /// Storage service for file I/O. Set during [loadFromDisk].
  StorageService? _storage;

  static const _fileName = 'Area Configuration.md';

  /// The current in-memory config.
  UnifiedAreaConfig get config => _config;

  /// Loads a pre-built config directly (for testing or programmatic setup).
  void loadFromConfig(UnifiedAreaConfig config) {
    _config = config;
  }

  // ── Lookups ──

  /// Looks up the area entry for exact coordinates.
  AreaConfigEntry? lookupByCoord(int x, int y) => _config.lookupByCoord(x, y);

  /// Returns the next background image for an area (cycling), or null.
  ///
  /// Advances the cycle index each call. Resets when area has no backgrounds.
  String? getBackgroundForArea(String areaName) {
    final entry = _config.areas[areaName];
    if (entry == null || entry.backgrounds.isEmpty) return null;
    final index = _backgroundCycleIndex[areaName] ?? 0;
    final bg = entry.backgrounds[index % entry.backgrounds.length];
    return bg;
  }

  /// Advances the background cycle to the next entry for [areaName].
  void advanceBackgroundCycle(String areaName) {
    final entry = _config.areas[areaName];
    if (entry == null || entry.backgrounds.isEmpty) return;
    final index = _backgroundCycleIndex[areaName] ?? 0;
    _backgroundCycleIndex[areaName] = (index + 1) % entry.backgrounds.length;
  }

  /// Returns the next music track for an area (cycling), or null.
  String? getMusicForArea(String areaName) {
    final entry = _config.areas[areaName];
    if (entry == null || entry.music.isEmpty) return null;
    final index = _musicCycleIndex[areaName] ?? 0;
    return entry.music[index % entry.music.length];
  }

  /// Advances the music cycle to the next entry for [areaName].
  void advanceMusicCycle(String areaName) {
    final entry = _config.areas[areaName];
    if (entry == null || entry.music.isEmpty) return;
    final index = _musicCycleIndex[areaName] ?? 0;
    _musicCycleIndex[areaName] = (index + 1) % entry.music.length;
  }

  /// Returns all area names in the config.
  Iterable<String> get areaNames => _config.areaNames;

  /// Returns the battle themes list.
  List<String> get battleThemes => List.unmodifiable(_config.battleThemes);

  /// Returns all backgrounds for an area.
  List<String> getBackgroundsForArea(String areaName) {
    return _config.areas[areaName]?.backgrounds ?? const [];
  }

  /// Returns all music tracks for an area.
  List<String> getMusicListForArea(String areaName) {
    return _config.areas[areaName]?.music ?? const [];
  }

  /// Returns all user-configured music as a flat map (area → first track).
  ///
  /// For backwards compatibility with [AreaAudioManager.loadUserTrackMap].
  Map<String, String> get userTrackMap {
    final map = <String, String>{};
    for (final entry in _config.areas.values) {
      if (entry.music.isNotEmpty) {
        map[entry.name] = entry.music.first;
      }
    }
    return map;
  }

  /// Returns all user-configured backgrounds as a flat map (area → first image).
  Map<String, String> get userImageMap {
    final map = <String, String>{};
    for (final entry in _config.areas.values) {
      if (entry.backgrounds.isNotEmpty) {
        map[entry.name] = entry.backgrounds.first;
      }
    }
    return map;
  }

  // ── Mutations ──

  /// Renames an area, transferring all coordinates, backgrounds, and music.
  void renameArea(String oldName, String newName) {
    final entry = _config.areas[oldName];
    if (entry == null || newName.isEmpty || oldName == newName) return;
    final areas = Map<String, AreaConfigEntry>.from(_config.areas);
    areas.remove(oldName);
    areas[newName] = entry.copyWith(name: newName);
    _config = UnifiedAreaConfig(
      areas: areas,
      battleThemes: _config.battleThemes,
    );
    // Transfer cycle indices.
    if (_backgroundCycleIndex.containsKey(oldName)) {
      _backgroundCycleIndex[newName] = _backgroundCycleIndex.remove(oldName)!;
    }
    if (_musicCycleIndex.containsKey(oldName)) {
      _musicCycleIndex[newName] = _musicCycleIndex.remove(oldName)!;
    }
    _saveToDisk();
  }

  /// Creates or updates an area entry with the given coordinate.
  void addCoordinateToArea(String areaName, int x, int y) {
    final coordStr = '$x,$y';
    final entry = _getOrCreateEntry(areaName);
    if (entry.coordinates.contains(coordStr)) return;
    _updateEntry(entry.copyWith(
      coordinates: [...entry.coordinates, coordStr],
    ));
    _saveToDisk();
  }

  /// Adds a background image for an area. If the path already exists, no-op.
  void addBackgroundForArea(String areaName, String filePath) {
    final entry = _getOrCreateEntry(areaName);
    if (entry.backgrounds.contains(filePath)) return;
    _updateEntry(entry.copyWith(
      backgrounds: [...entry.backgrounds, filePath],
    ));
    _saveToDisk();
  }

  /// Removes a background image from an area.
  void removeBackgroundFromArea(String areaName, String filePath) {
    final entry = _config.areas[areaName];
    if (entry == null) return;
    final updated = entry.backgrounds.where((b) => b != filePath).toList();
    _updateEntry(entry.copyWith(backgrounds: updated));
    _backgroundCycleIndex.remove(areaName);
    _saveToDisk();
  }

  /// Adds a music track for an area. If the path already exists, no-op.
  void addMusicForArea(String areaName, String filePath) {
    final entry = _getOrCreateEntry(areaName);
    if (entry.music.contains(filePath)) return;
    _updateEntry(entry.copyWith(
      music: [...entry.music, filePath],
    ));
    _saveToDisk();
  }

  /// Removes a music track from an area.
  void removeMusicFromArea(String areaName, String filePath) {
    final entry = _config.areas[areaName];
    if (entry == null) return;
    final updated = entry.music.where((m) => m != filePath).toList();
    _updateEntry(entry.copyWith(music: updated));
    _musicCycleIndex.remove(areaName);
    _saveToDisk();
  }

  /// Sets a single music track for an area, replacing all existing tracks.
  void setMusicForArea(String areaName, String filePath) {
    final entry = _getOrCreateEntry(areaName);
    _updateEntry(entry.copyWith(music: [filePath]));
    _musicCycleIndex.remove(areaName);
    _saveToDisk();
  }

  /// Removes all music for an area.
  void removeAllMusicForArea(String areaName) {
    final entry = _config.areas[areaName];
    if (entry == null) return;
    _updateEntry(entry.copyWith(music: []));
    _musicCycleIndex.remove(areaName);
    _saveToDisk();
  }

  /// Sets a single background for an area, replacing all existing.
  void setBackgroundForArea(String areaName, String filePath) {
    final entry = _getOrCreateEntry(areaName);
    _updateEntry(entry.copyWith(backgrounds: [filePath]));
    _backgroundCycleIndex.remove(areaName);
    _saveToDisk();
  }

  /// Removes all backgrounds for an area.
  void removeAllBackgroundsForArea(String areaName) {
    final entry = _config.areas[areaName];
    if (entry == null) return;
    _updateEntry(entry.copyWith(backgrounds: []));
    _backgroundCycleIndex.remove(areaName);
    _saveToDisk();
  }

  /// Adds a battle theme.
  void addBattleTheme(String filePath) {
    _config = UnifiedAreaConfig(
      areas: _config.areas,
      battleThemes: [..._config.battleThemes, filePath],
    );
    _saveToDisk();
  }

  /// Removes a battle theme at index.
  void removeBattleThemeAt(int index) {
    if (index < 0 || index >= _config.battleThemes.length) return;
    final themes = List<String>.from(_config.battleThemes)..removeAt(index);
    _config = UnifiedAreaConfig(
      areas: _config.areas,
      battleThemes: themes,
    );
    _saveToDisk();
  }

  /// Reorders battle themes.
  void reorderBattleThemes(int oldIndex, int newIndex) {
    final themes = List<String>.from(_config.battleThemes);
    if (oldIndex < newIndex) newIndex--;
    final item = themes.removeAt(oldIndex);
    themes.insert(newIndex, item);
    _config = UnifiedAreaConfig(
      areas: _config.areas,
      battleThemes: themes,
    );
    _saveToDisk();
  }

  // ── Internal helpers ──

  AreaConfigEntry _getOrCreateEntry(String areaName) {
    return _config.areas[areaName] ?? AreaConfigEntry(name: areaName);
  }

  void _updateEntry(AreaConfigEntry entry) {
    final areas = Map<String, AreaConfigEntry>.from(_config.areas);
    // Remove entry if it's now empty (no coords, backgrounds, or music).
    if (entry.coordinates.isEmpty &&
        entry.backgrounds.isEmpty &&
        entry.music.isEmpty) {
      areas.remove(entry.name);
    } else {
      areas[entry.name] = entry;
    }
    _config = UnifiedAreaConfig(
      areas: areas,
      battleThemes: _config.battleThemes,
    );
  }

  // ── Persistence ──

  /// Loads the unified config from disk, migrating from old files if needed.
  Future<void> loadFromDisk(StorageService storage) async {
    _storage = storage;
    try {
      final contents = await storage.readFile(_fileName);
      if (contents.trim().isNotEmpty) {
        _config = MarkdownConfigParser.parseUnifiedAreaConfig(contents);
        _persistEnabled = true;
        return;
      }

      // No unified file — try migrating from old files (desktop only).
      await _migrateFromOldFiles(storage);
    } catch (e) {
      debugPrint('UnifiedAreaConfigManager.loadFromDisk: $e');
    }
    _persistEnabled = true;
  }

  /// Merges old config files into the unified format.
  ///
  /// Migration reads from CWD and legacy app-documents paths using `dart:io`
  /// directly. This is inherently desktop-only and will be skipped on web
  /// (the files simply won't exist).
  Future<void> _migrateFromOldFiles(StorageService storage) async {
    // 1. Old Area Configuration.md from CWD (coord + audio entries).
    // Desktop only — web returns empty map.
    final areas = loadLegacyCwdConfig();
    var battleThemes = <String>[];

    // 2. Old area-audio.md (user tracks + battle themes).
    try {
      final legacyAudioContents = await storage.readFile('area-audio.md');
      if (legacyAudioContents.trim().isNotEmpty) {
        final parsed = MarkdownConfigParser.parseAreaAudio(legacyAudioContents);
        for (final MapEntry(:key, :value) in parsed.tracks.entries) {
          final existing = areas[key] ?? AreaConfigEntry(name: key);
          if (!existing.music.contains(value)) {
            areas[key] = existing.copyWith(
              music: [...existing.music, value],
            );
          }
        }
        battleThemes = parsed.battleThemes;
      }
    } catch (e) {
      debugPrint('Migration: old audio config error: $e');
    }

    // 3. Old area-images.md (backgrounds).
    try {
      final legacyImagesContents = await storage.readFile('area-images.md');
      if (legacyImagesContents.trim().isNotEmpty) {
        final parsed = MarkdownConfigParser.parseAreaTable(legacyImagesContents);
        for (final MapEntry(:key, :value) in parsed.entries) {
          final existing = areas[key] ?? AreaConfigEntry(name: key);
          if (!existing.backgrounds.contains(value)) {
            areas[key] = existing.copyWith(
              backgrounds: [...existing.backgrounds, value],
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Migration: old images config error: $e');
    }

    _config = UnifiedAreaConfig(areas: areas, battleThemes: battleThemes);

    // Save the migrated config if there's anything to save.
    if (areas.isNotEmpty || battleThemes.isNotEmpty) {
      _persistEnabled = true;
      await _saveToDiskAsync();
    }
  }

  /// Persists current config to disk (fire-and-forget).
  void _saveToDisk() {
    if (!_persistEnabled || _storage == null) return;
    _saveToDiskAsync();
  }

  /// Persists current config to disk.
  Future<void> _saveToDiskAsync() async {
    try {
      final md = MarkdownConfigParser.serializeUnifiedAreaConfig(_config);
      await _storage!.writeFile(_fileName, md);
    } catch (e) {
      debugPrint('UnifiedAreaConfigManager._saveToDisk: $e');
    }
  }
}
