import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/area_config.dart';

/// Detects the player's current area from coordinates or text patterns.
///
/// Uses a two-tier approach:
/// 1. **Primary**: Coordinate lookup against area bounding boxes from
///    `area_definitions.json`.
/// 2. **Fallback**: Text pattern matching on room descriptions for when
///    coordinate data is unavailable.
class AreaDetector {
  List<AreaConfig> _areas = [];
  final Map<String, RegExp> _textPatterns = {};
  String _currentArea = 'Unknown';

  /// The currently detected area name.
  String get currentArea => _currentArea;

  /// All loaded area configurations.
  List<AreaConfig> get areas => List.unmodifiable(_areas);

  /// Loads area definitions from the bundled JSON asset.
  Future<void> loadAreaDefinitions() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/area_definitions.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final areaList = json['areas'] as List<dynamic>;
      _areas = areaList
          .map((a) => AreaConfig.fromJson(a as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('AreaDetector.loadAreaDefinitions error: $e');
      _areas = [];
    }
  }

  /// Loads area definitions from a parsed list (for user-customized configs).
  void loadFromList(List<AreaConfig> areas) {
    _areas = List.of(areas);
  }

  /// Adds a text-based detection pattern for an area.
  ///
  /// Used as a fallback when coordinates are not available. The [pattern]
  /// is matched against room descriptions and movement messages.
  void addTextPattern(String areaName, String pattern) {
    _textPatterns[areaName] = RegExp(pattern, caseSensitive: false);
  }

  /// Detects the area from coordinates.
  ///
  /// Returns the area name if found, or `null` if no area matches.
  String? detectFromCoordinates(int x, int y) {
    for (final area in _areas) {
      if (area.contains(x, y)) {
        return area.name;
      }
    }
    return null;
  }

  /// Detects the area from room description text.
  ///
  /// Returns the area name if a text pattern matches, or `null`.
  String? detectFromText(String roomText) {
    for (final entry in _textPatterns.entries) {
      if (entry.value.hasMatch(roomText)) {
        return entry.key;
      }
    }

    // Built-in heuristics for common AA areas.
    // Inns checked first: "Ancient Inn of Tantallon" must match Inns, not Tantallon.
    if (_matchesAny(roomText, _innsPatterns)) return 'Inns';
    if (_matchesAny(roomText, _tantallonPatterns)) return 'Tantallon';
    if (_matchesAny(roomText, _wildernessPatterns)) return 'Wilderness';

    return null;
  }

  /// Hybrid detection: prefers coordinates, falls back to text.
  ///
  /// Updates [currentArea] and returns the detected area name.
  String detect({int? x, int? y, String? roomText}) {
    String? detected;

    // Try coordinates first.
    if (x != null && y != null) {
      detected = detectFromCoordinates(x, y);
    }

    // Fall back to text matching.
    if (detected == null && roomText != null && roomText.isNotEmpty) {
      detected = detectFromText(roomText);
    }

    final newArea = detected ?? _currentArea;
    _currentArea = newArea;
    return newArea;
  }

  /// Returns the [AreaConfig] for the given area name, or `null`.
  AreaConfig? getAreaConfig(String areaName) {
    for (final area in _areas) {
      if (area.name == areaName) return area;
    }
    return null;
  }

  /// Resets the detector to initial state.
  void reset() {
    _currentArea = 'Unknown';
  }

  // ── Built-in heuristics for common AA areas ──

  static final List<RegExp> _innsPatterns = [
    RegExp(r'Ancient Inn of Tantallon', caseSensitive: false),
    RegExp(r'Dalair, Taverna', caseSensitive: false),
    RegExp(r'Entrance of Ancient Bliss Inn', caseSensitive: false),
    RegExp(r'The common room', caseSensitive: false),
    RegExp(r'Ancient Bliss chess room', caseSensitive: false),
    RegExp(r"The Inn's small bar", caseSensitive: false),
    RegExp(r'The inns reception', caseSensitive: false),
    RegExp(r'Village pub', caseSensitive: false),
    RegExp(r'Small room of pub', caseSensitive: false),
    RegExp(r'Golden Ducat draughts room', caseSensitive: false),
    RegExp(r'Common room', caseSensitive: false),
    RegExp(r'Reception area', caseSensitive: false),
  ];

  static final List<RegExp> _tantallonPatterns = [
    RegExp(r'Tantallon', caseSensitive: false),
    RegExp(r'Town Square', caseSensitive: false),
    RegExp(r'Main Street of Tantallon', caseSensitive: false),
    RegExp(r"Hanza's Map Shop", caseSensitive: false),
  ];

  static final List<RegExp> _wildernessPatterns = [
    RegExp(r'dusty road', caseSensitive: false),
    RegExp(r'grassy plain', caseSensitive: false),
    RegExp(r'forest path', caseSensitive: false),
    RegExp(r'winding trail', caseSensitive: false),
  ];

  bool _matchesAny(String text, List<RegExp> patterns) {
    return patterns.any((p) => p.hasMatch(text));
  }
}
