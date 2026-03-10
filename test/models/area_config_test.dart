import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/area_config.dart';

void main() {
  group('AreaBounds - contains', () {
    const bounds = AreaBounds(xMin: -5, xMax: 10, yMin: 0, yMax: 20);

    test('point inside bounds returns true', () {
      expect(bounds.contains(0, 10), isTrue);
    });

    test('point on xMin boundary returns true', () {
      expect(bounds.contains(-5, 10), isTrue);
    });

    test('point on xMax boundary returns true', () {
      expect(bounds.contains(10, 10), isTrue);
    });

    test('point on yMin boundary returns true', () {
      expect(bounds.contains(0, 0), isTrue);
    });

    test('point on yMax boundary returns true', () {
      expect(bounds.contains(0, 20), isTrue);
    });

    test('point outside xMin returns false', () {
      expect(bounds.contains(-6, 10), isFalse);
    });

    test('point outside xMax returns false', () {
      expect(bounds.contains(11, 10), isFalse);
    });

    test('point outside yMin returns false', () {
      expect(bounds.contains(0, -1), isFalse);
    });

    test('point outside yMax returns false', () {
      expect(bounds.contains(0, 21), isFalse);
    });

    test('handles all-negative coordinate bounds', () {
      const negBounds = AreaBounds(xMin: -20, xMax: -10, yMin: -30, yMax: -5);
      expect(negBounds.contains(-15, -15), isTrue);
      expect(negBounds.contains(0, 0), isFalse);
    });
  });

  group('AreaConfig - contains', () {
    test('delegates to bounds.contains', () {
      const config = AreaConfig(
        name: 'Forest',
        bounds: AreaBounds(xMin: 0, xMax: 10, yMin: 0, yMax: 10),
      );
      expect(config.contains(5, 5), isTrue);
      expect(config.contains(15, 15), isFalse);
    });
  });

  group('AreaConfig - JSON round-trip', () {
    test('preserves all fields including audio', () {
      const original = AreaConfig(
        name: 'Dark Forest',
        bounds: AreaBounds(xMin: -10, xMax: 10, yMin: -5, yMax: 5),
        audio: AreaAudio(track: 'forest.mp3', volume: 0.5, fadeMs: 3000),
        theme: 'dark',
      );

      final json = original.toJson();
      final restored = AreaConfig.fromJson(json);

      expect(restored.name, 'Dark Forest');
      expect(restored.bounds.xMin, -10);
      expect(restored.bounds.xMax, 10);
      expect(restored.bounds.yMin, -5);
      expect(restored.bounds.yMax, 5);
      expect(restored.audio!.track, 'forest.mp3');
      expect(restored.audio!.volume, 0.5);
      expect(restored.audio!.fadeMs, 3000);
      expect(restored.theme, 'dark');
    });

    test('preserves config without audio', () {
      const original = AreaConfig(
        name: 'Silent Zone',
        bounds: AreaBounds(xMin: 0, xMax: 5, yMin: 0, yMax: 5),
      );

      final json = original.toJson();
      final restored = AreaConfig.fromJson(json);

      expect(restored.audio, isNull);
      expect(restored.theme, isNull);
    });
  });

  group('AreaAudio - JSON round-trip', () {
    test('preserves all fields', () {
      const original = AreaAudio(
        track: 'ambient.mp3',
        volume: 0.8,
        fadeMs: 1500,
      );

      final json = original.toJson();
      final restored = AreaAudio.fromJson(json);

      expect(restored.track, 'ambient.mp3');
      expect(restored.volume, 0.8);
      expect(restored.fadeMs, 1500);
    });

    test('uses defaults for missing volume and fadeMs', () {
      final json = {'track': 'ambient.mp3'};
      final audio = AreaAudio.fromJson(json);
      expect(audio.volume, 0.7);
      expect(audio.fadeMs, 2000);
    });
  });

  group('AreaBounds - JSON round-trip', () {
    test('preserves all fields', () {
      const original = AreaBounds(xMin: -100, xMax: 200, yMin: -50, yMax: 75);
      final json = original.toJson();
      final restored = AreaBounds.fromJson(json);

      expect(restored.xMin, -100);
      expect(restored.xMax, 200);
      expect(restored.yMin, -50);
      expect(restored.yMax, 75);
    });
  });
}
