import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/area_config.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';

void main() {
  late AreaDetector detector;

  setUp(() {
    detector = AreaDetector();
    detector.loadFromList([
      const AreaConfig(
        name: 'Tantallon',
        bounds: AreaBounds(xMin: -2, xMax: 2, yMin: -2, yMax: 2),
      ),
      const AreaConfig(
        name: 'Northern Plains',
        bounds: AreaBounds(xMin: -5, xMax: 5, yMin: 3, yMax: 10),
      ),
      const AreaConfig(
        name: 'Dwarven Mines',
        bounds: AreaBounds(xMin: -8, xMax: -6, yMin: 5, yMax: 8),
      ),
    ]);
  });

  group('AreaDetector - Coordinate detection', () {
    test('detects Tantallon at origin', () {
      expect(detector.detectFromCoordinates(0, 0), 'Tantallon');
    });

    test('detects Tantallon at boundary', () {
      expect(detector.detectFromCoordinates(2, 2), 'Tantallon');
      expect(detector.detectFromCoordinates(-2, -2), 'Tantallon');
    });

    test('detects Northern Plains', () {
      expect(detector.detectFromCoordinates(0, 5), 'Northern Plains');
    });

    test('returns null for unknown coordinates', () {
      expect(detector.detectFromCoordinates(100, 100), isNull);
    });

    test('first matching area wins on overlap', () {
      // (0, 3) could match Northern Plains (yMin=3)
      // but not Tantallon (yMax=2).
      expect(detector.detectFromCoordinates(0, 3), 'Northern Plains');
    });
  });

  group('AreaDetector - Text detection', () {
    test('detects from built-in heuristics', () {
      expect(detector.detectFromText('Town Square of Tantallon'),
          'Tantallon');
    });

    test('detects from custom pattern', () {
      detector.addTextPattern('Dark Castle', r'dark castle|shadow keep');
      expect(detector.detectFromText('You enter the dark castle.'),
          'Dark Castle');
    });

    test('returns null for unrecognized text', () {
      expect(detector.detectFromText('A completely unknown place.'), isNull);
    });

    test('text detection is case-insensitive', () {
      expect(detector.detectFromText('TANTALLON TOWN SQUARE'),
          'Tantallon');
    });
  });

  group('AreaDetector - Hybrid detection', () {
    test('prefers coordinates over text', () {
      final area = detector.detect(x: 0, y: 0, roomText: 'Northern Plains');
      expect(area, 'Tantallon'); // Coordinates say Tantallon.
    });

    test('falls back to text when coordinates are null', () {
      final area = detector.detect(roomText: 'Town Square of Tantallon');
      expect(area, 'Tantallon');
    });

    test('updates currentArea', () {
      detector.detect(x: 0, y: 5);
      expect(detector.currentArea, 'Northern Plains');
    });

    test('retains last area when nothing matches', () {
      detector.detect(x: 0, y: 0); // Tantallon
      detector.detect(x: 999, y: 999); // Unknown, keep Tantallon
      expect(detector.currentArea, 'Tantallon');
    });

    test('reset clears current area', () {
      detector.detect(x: 0, y: 0);
      detector.reset();
      expect(detector.currentArea, 'Unknown');
    });
  });

  group('AreaDetector - Inns text detection', () {
    test('detects inn rooms', () {
      const rooms = [
        'Ancient Inn of Tantallon',
        'Dalair, Taverna',
        'Entrance of Ancient Bliss Inn',
        'The common room',
        'Ancient Bliss chess room',
        "The Inn's small bar",
        'The inns reception',
        'Village pub',
        'Small room of pub',
        'Golden Ducat draughts room',
        'Common room',
        'Reception area',
      ];
      for (final room in rooms) {
        expect(detector.detectFromText(room), 'Inns',
            reason: 'Expected "$room" to detect as Inns');
      }
    });

    test('Ancient Inn of Tantallon resolves to Inns not Tantallon', () {
      expect(
          detector.detectFromText('Ancient Inn of Tantallon'), 'Inns');
    });

    test('inn detection is case-insensitive', () {
      expect(detector.detectFromText('VILLAGE PUB'), 'Inns');
      expect(detector.detectFromText('the common room'), 'Inns');
    });
  });

  group('AreaDetector - getAreaConfig', () {
    test('returns config for known area', () {
      final config = detector.getAreaConfig('Tantallon');
      expect(config, isNotNull);
      expect(config!.name, 'Tantallon');
    });

    test('returns null for unknown area', () {
      expect(detector.getAreaConfig('Atlantis'), isNull);
    });
  });

  group('AreaConfig - serialization', () {
    test('round-trips through JSON', () {
      const original = AreaConfig(
        name: 'Test',
        bounds: AreaBounds(xMin: -1, xMax: 1, yMin: -1, yMax: 1),
        audio: AreaAudio(track: 'test.mp3', volume: 0.5, fadeMs: 1000),
        theme: 'dungeon',
      );

      final json = original.toJson();
      final restored = AreaConfig.fromJson(json);

      expect(restored.name, 'Test');
      expect(restored.bounds.xMin, -1);
      expect(restored.audio!.track, 'test.mp3');
      expect(restored.audio!.volume, 0.5);
      expect(restored.theme, 'dungeon');
    });
  });
}
