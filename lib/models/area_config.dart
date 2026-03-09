/// Defines a named area with coordinate boundaries and associated audio.
class AreaConfig {
  final String name;
  final AreaBounds bounds;
  final AreaAudio? audio;
  final String? theme;

  const AreaConfig({
    required this.name,
    required this.bounds,
    this.audio,
    this.theme,
  });

  /// Whether the given coordinates fall within this area's bounds.
  bool contains(int x, int y) => bounds.contains(x, y);

  factory AreaConfig.fromJson(Map<String, dynamic> json) {
    return AreaConfig(
      name: json['name'] as String,
      bounds: AreaBounds.fromJson(json['bounds'] as Map<String, dynamic>),
      audio: json['audio'] != null
          ? AreaAudio.fromJson(json['audio'] as Map<String, dynamic>)
          : null,
      theme: json['theme'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'bounds': bounds.toJson(),
        if (audio != null) 'audio': audio!.toJson(),
        if (theme != null) 'theme': theme,
      };
}

/// Axis-aligned bounding box defined by min/max X and Y coordinates.
class AreaBounds {
  final int xMin;
  final int xMax;
  final int yMin;
  final int yMax;

  const AreaBounds({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });

  bool contains(int x, int y) =>
      x >= xMin && x <= xMax && y >= yMin && y <= yMax;

  factory AreaBounds.fromJson(Map<String, dynamic> json) {
    return AreaBounds(
      xMin: json['xMin'] as int,
      xMax: json['xMax'] as int,
      yMin: json['yMin'] as int,
      yMax: json['yMax'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'xMin': xMin,
        'xMax': xMax,
        'yMin': yMin,
        'yMax': yMax,
      };
}

/// Audio configuration for an area (track file, volume, fade timing).
class AreaAudio {
  final String track;
  final double volume;
  final int fadeMs;

  const AreaAudio({
    required this.track,
    this.volume = 0.7,
    this.fadeMs = 2000,
  });

  factory AreaAudio.fromJson(Map<String, dynamic> json) {
    return AreaAudio(
      track: json['track'] as String,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.7,
      fadeMs: (json['fadeMs'] as int?) ?? 2000,
    );
  }

  Map<String, dynamic> toJson() => {
        'track': track,
        'volume': volume,
        'fadeMs': fadeMs,
      };
}
