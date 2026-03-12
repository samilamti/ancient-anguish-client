import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

/// Manages area-to-image file path mappings for terminal background images.
class AreaBackgroundManager {
  final Map<String, String> _userImageMap = {};

  /// Sets a user-configured image file path for an area.
  void setImageForArea(String areaName, String filePath) {
    _userImageMap[areaName] = filePath;
    _saveToDisk();
  }

  /// Removes a user-configured image mapping for an area.
  void removeImageForArea(String areaName) {
    _userImageMap.remove(areaName);
    _saveToDisk();
  }

  /// Returns all user-configured image mappings.
  Map<String, String> get userImageMap => Map.unmodifiable(_userImageMap);

  /// Loads user image mappings from a map (e.g., from settings storage).
  void loadUserImageMap(Map<String, String> map) {
    _userImageMap.clear();
    _userImageMap.addAll(map);
  }

  /// Returns the image file path for an area, or null if not mapped.
  String? getImageForArea(String areaName) {
    return _userImageMap[areaName];
  }

  // ── Persistence ──

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/AncientAnguishClient/background_images.json');
  }

  /// Loads saved mappings from disk. Call once at startup.
  Future<void> loadFromDisk() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return;
      final contents = await file.readAsString();
      if (contents.trim().isEmpty) return;
      final decoded = jsonDecode(contents);
      if (decoded is Map) {
        _userImageMap.clear();
        _userImageMap.addAll(decoded.cast<String, String>());
      }
    } catch (e) {
      debugPrint('AreaBackgroundManager.loadFromDisk: $e');
    }
  }

  /// Persists current mappings to disk.
  Future<void> _saveToDisk() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_userImageMap));
    } catch (e) {
      debugPrint('AreaBackgroundManager._saveToDisk: $e');
    }
  }
}
