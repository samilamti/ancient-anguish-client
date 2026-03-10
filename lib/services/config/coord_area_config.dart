import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/coord_area_entry.dart';

/// Parses and stores the coordinate-to-area configuration from Area Configuration.md.
///
/// File format (tab-separated):
///   x,y\tAreaName\t"path/to/audio.mp3"
///   AreaName\t"path/to/audio.mp3"
///
/// Lines starting with `#` are comments. The audio path (third column for
/// coordinate entries, second column for area-only entries) is optional and
/// may be quoted. Area-only entries (no coordinates) provide audio mappings
/// for areas detected by text patterns (e.g., Inns inside Tantallon).
class CoordAreaConfig {
  final Map<String, CoordAreaEntry> _entries = {};

  /// Area-name → audio-path mappings for areas without specific coordinates.
  final Map<String, String> _areaAudioMap = {};

  /// All loaded coordinate entries.
  List<CoordAreaEntry> get entries => _entries.values.toList();

  /// Area-only audio mappings (no coordinates).
  Map<String, String> get areaAudioMap => Map.unmodifiable(_areaAudioMap);

  /// Looks up the entry for exact coordinates, or null if not mapped.
  CoordAreaEntry? lookup(int x, int y) {
    return _entries[CoordAreaEntry.coordKey(x, y)];
  }

  /// Loads configuration from a file path asynchronously.
  Future<void> loadFromFile(String filePath) async {
    _entries.clear();
    _areaAudioMap.clear();
    try {
      final file = File(filePath);
      if (!await file.exists()) return;

      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
        final entry = _parseLine(line);
        if (entry != null) {
          _entries[entry.key] = entry;
        }
      }
    } catch (e) {
      debugPrint('CoordAreaConfig.loadFromFile error: $e');
    }
  }

  /// Loads configuration from a file path synchronously.
  ///
  /// Preferred for use in provider `build()` to avoid race conditions.
  void loadFromFileSync(String filePath) {
    _entries.clear();
    _areaAudioMap.clear();
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;

      final lines = file.readAsLinesSync();
      for (final line in lines) {
        if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
        final entry = _parseLine(line);
        if (entry != null) {
          _entries[entry.key] = entry;
        }
      }
    } catch (e) {
      debugPrint('CoordAreaConfig.loadFromFileSync error: $e');
    }
  }

  static final RegExp _coordRegex = RegExp(r'^(-?\d+),(-?\d+)$');

  CoordAreaEntry? _parseLine(String line) {
    final parts = line.split('\t');
    if (parts.length < 2) return null;

    final coordMatch = _coordRegex.firstMatch(parts[0].trim());
    if (coordMatch == null) {
      // Try area-only format: AreaName\t"audio path"
      _parseAreaOnly(parts);
      return null;
    }

    final x = int.parse(coordMatch.group(1)!);
    final y = int.parse(coordMatch.group(2)!);
    final areaName = parts[1].trim();
    if (areaName.isEmpty) return null;

    String? audioPath;
    if (parts.length >= 3) {
      audioPath = parts[2].trim();
      // Remove surrounding quotes if present.
      if (audioPath.startsWith('"') && audioPath.endsWith('"')) {
        audioPath = audioPath.substring(1, audioPath.length - 1);
      }
      if (audioPath.isEmpty) audioPath = null;
    }

    return CoordAreaEntry(
      x: x,
      y: y,
      areaName: areaName,
      audioPath: audioPath,
    );
  }

  /// Parses an area-only audio mapping line: AreaName\t"audio path".
  void _parseAreaOnly(List<String> parts) {
    final areaName = parts[0].trim();
    if (areaName.isEmpty) return;

    if (parts.length < 2) return;
    var audioPath = parts[1].trim();
    if (audioPath.startsWith('"') && audioPath.endsWith('"')) {
      audioPath = audioPath.substring(1, audioPath.length - 1);
    }
    if (audioPath.isEmpty) return;

    _areaAudioMap[areaName] = audioPath;
  }

  /// Resets all loaded entries.
  void reset() {
    _entries.clear();
    _areaAudioMap.clear();
  }
}
