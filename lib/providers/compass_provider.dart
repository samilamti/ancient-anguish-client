import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/known_locations.dart';
import '../models/known_location.dart';
import 'game_state_provider.dart';

/// A location is "nearby" (and appears on the navigation compass) when it
/// lies within this many stadia of the player.
const double kCompassRangeStadia = 10;

/// Known locations within [kCompassRangeStadia] of the player's current
/// position, sorted nearest first. Empty while coordinates are unknown
/// (indoors, not logged in, disconnected).
final nearbyLocationsProvider = Provider<List<NearbyLocation>>((ref) {
  final (x, y) =
      ref.watch(gameStateProvider.select((s) => (s.x, s.y)));
  if (x == null || y == null) return const [];

  final nearby = <NearbyLocation>[];
  for (final location in kKnownLocations) {
    final measured = NearbyLocation.measure(
      location, x, y,
      maxDistance: kCompassRangeStadia,
    );
    if (measured != null) nearby.add(measured);
  }
  nearby.sort((a, b) => a.distance.compareTo(b.distance));
  return nearby;
});
