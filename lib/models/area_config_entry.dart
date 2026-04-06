/// A single area's unified configuration: coordinates, backgrounds, and music.
class AreaConfigEntry {
  final String name;
  final List<String> coordinates; // "x,y" strings
  final List<String> backgrounds; // image file paths
  final List<String> music; // audio file paths

  const AreaConfigEntry({
    required this.name,
    this.coordinates = const [],
    this.backgrounds = const [],
    this.music = const [],
  });

  AreaConfigEntry copyWith({
    String? name,
    List<String>? coordinates,
    List<String>? backgrounds,
    List<String>? music,
  }) {
    return AreaConfigEntry(
      name: name ?? this.name,
      coordinates: coordinates ?? this.coordinates,
      backgrounds: backgrounds ?? this.backgrounds,
      music: music ?? this.music,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AreaConfigEntry &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          _listEquals(coordinates, other.coordinates) &&
          _listEquals(backgrounds, other.backgrounds) &&
          _listEquals(music, other.music);

  @override
  int get hashCode =>
      name.hashCode ^
      Object.hashAll(coordinates) ^
      Object.hashAll(backgrounds) ^
      Object.hashAll(music);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The complete unified area configuration: all areas plus battle themes.
class UnifiedAreaConfig {
  final Map<String, AreaConfigEntry> areas;
  final List<String> battleThemes;

  /// Coordinate-to-area index for O(1) lookup.
  final Map<String, AreaConfigEntry> _coordIndex;

  UnifiedAreaConfig({
    Map<String, AreaConfigEntry>? areas,
    this.battleThemes = const [],
  })  : areas = areas ?? const {},
        _coordIndex = _buildCoordIndex(areas ?? const {});

  static Map<String, AreaConfigEntry> _buildCoordIndex(
      Map<String, AreaConfigEntry> areas) {
    final index = <String, AreaConfigEntry>{};
    for (final entry in areas.values) {
      for (final coord in entry.coordinates) {
        index[coord] = entry;
      }
    }
    return index;
  }

  /// Looks up the area entry for exact coordinates, or null if not mapped.
  AreaConfigEntry? lookupByCoord(int x, int y) {
    return _coordIndex['$x,$y'];
  }

  /// Returns all area names.
  Iterable<String> get areaNames => areas.keys;

  static const empty = _EmptyUnifiedAreaConfig();
}

class _EmptyUnifiedAreaConfig implements UnifiedAreaConfig {
  const _EmptyUnifiedAreaConfig();

  @override
  Map<String, AreaConfigEntry> get areas => const {};
  @override
  List<String> get battleThemes => const [];
  @override
  Map<String, AreaConfigEntry> get _coordIndex => const {};
  @override
  AreaConfigEntry? lookupByCoord(int x, int y) => null;
  @override
  Iterable<String> get areaNames => const [];
}
