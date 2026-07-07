import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/core/known_locations.dart';
import 'package:ancient_anguish_client/models/known_location.dart';

void main() {
  group('NearbyLocation.measure', () {
    const origin = KnownLocation('x', 'x', 0, 0, LocationKind.landmark);

    test('due north gives bearing 0 and direction N', () {
      const loc = KnownLocation('n', 'n', 0, 5, LocationKind.landmark);
      final measured = NearbyLocation.measure(loc, 0, 0, maxDistance: 10)!;
      expect(measured.distance, 5);
      expect(measured.bearing, closeTo(0, 1e-9));
      expect(measured.direction, 'N');
    });

    test('due east gives bearing π/2 and direction E', () {
      const loc = KnownLocation('e', 'e', 7, 0, LocationKind.landmark);
      final measured = NearbyLocation.measure(loc, 0, 0, maxDistance: 10)!;
      expect(measured.bearing, closeTo(1.5707963, 1e-6));
      expect(measured.direction, 'E');
    });

    test('southwest gives direction SW with normalized bearing', () {
      const loc = KnownLocation('sw', 'sw', -3, -3, LocationKind.landmark);
      final measured = NearbyLocation.measure(loc, 0, 0, maxDistance: 10)!;
      // 225° = 5π/4; atan2 would give a negative angle without wrapping.
      expect(measured.bearing, closeTo(3.9269908, 1e-6));
      expect(measured.direction, 'SW');
    });

    test('measures from the player position, not the origin', () {
      final measured =
          NearbyLocation.measure(origin, 3, 4, maxDistance: 10)!;
      expect(measured.distance, 5);
      expect(measured.direction, 'SW');
    });

    test('returns null beyond maxDistance, keeps the boundary', () {
      const far = KnownLocation('far', 'far', 0, 11, LocationKind.landmark);
      const edge = KnownLocation('edge', 'edge', 0, 10, LocationKind.landmark);
      expect(NearbyLocation.measure(far, 0, 0, maxDistance: 10), isNull);
      expect(NearbyLocation.measure(edge, 0, 0, maxDistance: 10), isNotNull);
    });

    test('direction wraps around north from the west side', () {
      // 350° is closer to N than to NW.
      const loc = KnownLocation('nnw', 'nnw', -1, 6, LocationKind.landmark);
      final measured = NearbyLocation.measure(loc, 0, 0, maxDistance: 10)!;
      expect(measured.direction, 'N');
    });
  });

  group('kKnownLocations data integrity', () {
    test('carries the full official gazetteer', () {
      expect(kKnownLocations.length, greaterThan(150));
    });

    test('Tantallon is the map origin', () {
      final tantallon = kKnownLocations
          .firstWhere((l) => l.shortName == 'Tantallon');
      expect(tantallon.x, 0);
      expect(tantallon.y, 0);
      expect(tantallon.kind, LocationKind.city);
    });

    test('all entries have sane names and on-map coordinates', () {
      for (final location in kKnownLocations) {
        expect(location.name.trim(), isNotEmpty);
        expect(location.shortName.trim(), isNotEmpty);
        expect(location.name, isNot(contains('<')));
        // The official grid spans -17..80 east-west and -39..60
        // north-south; anything outside is a parser regression.
        expect(location.x, inInclusiveRange(-64, 100));
        expect(location.y, inInclusiveRange(-64, 80));
      }
    });
  });
}
