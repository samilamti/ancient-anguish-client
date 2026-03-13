import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import '../../models/area_config_entry.dart';
import 'coord_area_config.dart';
import 'markdown_config_parser.dart';

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

  static Future<String> _dir() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/AncientAnguishClient';
  }

  static Future<File> _file() async {
    return File('${await _dir()}/Area Configuration.md');
  }

  /// Loads the unified config from disk, migrating from old files if needed.
  Future<void> loadFromDisk() async {
    try {
      final file = await _file();
      if (file.existsSync()) {
        final contents = await file.readAsString();
        if (contents.trim().isNotEmpty) {
          _config = MarkdownConfigParser.parseUnifiedAreaConfig(contents);
          _persistEnabled = true;
          return;
        }
      }

      // No unified file — try migrating from old files.
      await _migrateFromOldFiles();
    } catch (e) {
      debugPrint('UnifiedAreaConfigManager.loadFromDisk: $e');
    }
    _persistEnabled = true;
  }

  /// Merges old config files into the unified format.
  Future<void> _migrateFromOldFiles() async {
    final appDir = await _dir();
    final areas = <String, AreaConfigEntry>{};
    var battleThemes = <String>[];

    // 1. Old Area Configuration.md from CWD (coord + audio entries).
    try {
      final oldCoordFile = File('Area Configuration.md');
      if (oldCoordFile.existsSync()) {
        final coordConfig = CoordAreaConfig();
        coordConfig.loadFromFileSync('Area Configuration.md');
        for (final entry in coordConfig.entries) {
          final existing = areas[entry.areaName] ??
              AreaConfigEntry(name: entry.areaName);
          areas[entry.areaName] = existing.copyWith(
            coordinates: [
              ...existing.coordinates,
              '${entry.x},${entry.y}',
            ],
            music: entry.audioPath != null &&
                    !existing.music.contains(entry.audioPath)
                ? [...existing.music, entry.audioPath!]
                : null,
          );
        }
        // Area-only audio mappings.
        for (final MapEntry(:key, :value) in coordConfig.areaAudioMap.entries) {
          final existing = areas[key] ?? AreaConfigEntry(name: key);
          if (!existing.music.contains(value)) {
            areas[key] = existing.copyWith(
              music: [...existing.music, value],
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Migration: old coord config error: $e');
    }

    // 2. Old area-audio.md (user tracks + battle themes).
    try {
      final oldAudioFile = File('$appDir/area-audio.md');
      if (oldAudioFile.existsSync()) {
        final contents = await oldAudioFile.readAsString();
        if (contents.trim().isNotEmpty) {
          final parsed = MarkdownConfigParser.parseAreaAudio(contents);
          for (final MapEntry(:key, :value) in parsed.tracks.entries) {
            final existing = areas[key] ?? AreaConfigEntry(name: key);
            // User overrides replace coord-config tracks.
            if (!existing.music.contains(value)) {
              areas[key] = existing.copyWith(
                music: [...existing.music, value],
              );
            }
          }
          battleThemes = parsed.battleThemes;
        }
      }
    } catch (e) {
      debugPrint('Migration: old audio config error: $e');
    }

    // 3. Old area-images.md (backgrounds).
    try {
      final oldImagesFile = File('$appDir/area-images.md');
      if (oldImagesFile.existsSync()) {
        final contents = await oldImagesFile.readAsString();
        if (contents.trim().isNotEmpty) {
          final parsed = MarkdownConfigParser.parseAreaTable(contents);
          for (final MapEntry(:key, :value) in parsed.entries) {
            final existing = areas[key] ?? AreaConfigEntry(name: key);
            if (!existing.backgrounds.contains(value)) {
              areas[key] = existing.copyWith(
                backgrounds: [...existing.backgrounds, value],
              );
            }
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
    if (!_persistEnabled) return;
    _saveToDiskAsync();
  }

  /// Persists current config to disk.
  Future<void> _saveToDiskAsync() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      final md = MarkdownConfigParser.serializeUnifiedAreaConfig(_config);
      await file.writeAsString(md);
    } catch (e) {
      debugPrint('UnifiedAreaConfigManager._saveToDisk: $e');
    }
  }
}
