import 'dart:math' as math;

/// Category of a named map location, used to pick a representative icon
/// on the navigation compass.
enum LocationKind {
  city,
  village,
  bridge,
  cave,
  temple,
  camp,
  fortress,
  hall,
  farm,
  ruin,
  dwelling,
  coast,
  nature,
  landmark,
}

/// A named location from the official Ancient Anguish map, in map-room
/// coordinates centered on Tantallon (0, 0). x grows east, y grows north —
/// the same convention the game reports through the CLIENT prompt line.
class KnownLocation {
  /// Official name as written on the accessible map page,
  /// e.g. "the city of Norton".
  final String name;

  /// Compact label for the compass, e.g. "Norton".
  final String shortName;

  final int x;
  final int y;
  final LocationKind kind;

  const KnownLocation(this.name, this.shortName, this.x, this.y, this.kind);
}

/// A [KnownLocation] measured from the player's current position.
class NearbyLocation {
  final KnownLocation location;

  /// Straight-line distance in stadia (map rooms).
  final double distance;

  /// Bearing in radians, 0 = north, clockwise (π/2 = east).
  final double bearing;

  const NearbyLocation(this.location, this.distance, this.bearing);

  static const List<String> _windNames = [
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW',
  ];

  /// 8-wind compass direction name for [bearing], e.g. "NE".
  String get direction {
    final octant =
        ((bearing / (math.pi / 4)).round()) % _windNames.length;
    return _windNames[octant];
  }

  /// Measures [location] from player position ([px], [py]), or returns
  /// `null` when it is farther than [maxDistance] stadia away.
  static NearbyLocation? measure(
    KnownLocation location,
    int px,
    int py, {
    required double maxDistance,
  }) {
    final dx = (location.x - px).toDouble();
    final dy = (location.y - py).toDouble();
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > maxDistance) return null;
    var bearing = math.atan2(dx, dy);
    if (bearing < 0) bearing += 2 * math.pi;
    return NearbyLocation(location, distance, bearing);
  }
}
