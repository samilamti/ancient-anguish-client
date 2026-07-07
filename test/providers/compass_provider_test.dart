import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/compass_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';

void main() {
  late ProviderContainer container;
  late GameStateNotifier notifier;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        promptParserProvider.overrideWithValue(PromptParser()),
        areaDetectorProvider
            .overrideWith((ref) => Future.value(AreaDetector())),
        unifiedAreaConfigProvider
            .overrideWith((ref) => Future.value(UnifiedAreaConfigManager())),
      ],
    );
    notifier = container.read(gameStateProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  void moveTo(int x, int y) =>
      notifier.updateVitalsAndCoordinates(100, 100, 50, 50, x, y);

  group('nearbyLocationsProvider', () {
    test('is empty while coordinates are unknown', () {
      expect(container.read(nearbyLocationsProvider), isEmpty);
    });

    test('in Tantallon: finds the city itself first, sorted by distance', () {
      moveTo(0, 0);
      final nearby = container.read(nearbyLocationsProvider);

      expect(nearby, isNotEmpty);
      expect(nearby.first.location.shortName, 'Tantallon');
      expect(nearby.first.distance, 0);
      for (var i = 1; i < nearby.length; i++) {
        expect(
          nearby[i].distance,
          greaterThanOrEqualTo(nearby[i - 1].distance),
        );
      }
      for (final entry in nearby) {
        expect(entry.distance, lessThanOrEqualTo(kCompassRangeStadia));
      }
    });

    test('south of Tantallon the city reads as due north', () {
      moveTo(0, -3);
      final nearby = container.read(nearbyLocationsProvider);
      final tantallon = nearby
          .firstWhere((e) => e.location.shortName == 'Tantallon');
      expect(tantallon.distance, 3);
      expect(tantallon.direction, 'N');
    });

    test('is empty in the middle of the Mare Stellarum', () {
      moveTo(35, 15);
      expect(container.read(nearbyLocationsProvider), isEmpty);
    });

    test('recomputes when the player moves', () {
      moveTo(0, 0);
      final atTantallon = container.read(nearbyLocationsProvider);
      moveTo(11, 42);
      final atNorton = container.read(nearbyLocationsProvider);

      expect(atNorton.first.location.shortName, 'Norton');
      expect(atNorton, isNot(equals(atTantallon)));
    });
  });
}
