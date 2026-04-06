import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../models/area_config_entry.dart';
import 'coord_area_config.dart';

/// Reads the old CWD-based `Area Configuration.md` (desktop only).
///
/// Returns a map of area name → [AreaConfigEntry] with coordinates and music
/// parsed from the legacy tab-separated format.
Map<String, AreaConfigEntry> loadLegacyCwdConfig() {
  final areas = <String, AreaConfigEntry>{};
  try {
    final oldCoordFile = File('Area Configuration.md');
    if (oldCoordFile.existsSync()) {
      final coordConfig = CoordAreaConfig();
      coordConfig.loadFromFileSync('Area Configuration.md');
      for (final entry in coordConfig.entries) {
        final existing =
            areas[entry.areaName] ?? AreaConfigEntry(name: entry.areaName);
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
  return areas;
}
