import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/coord_area_entry.dart';

void main() {
  group('CoordAreaEntry', () {
    test('coordKey produces "x,y" format', () {
      expect(CoordAreaEntry.coordKey(3, 7), '3,7');
    });

    test('key getter matches static coordKey', () {
      const entry = CoordAreaEntry(x: 5, y: 10, areaName: 'Test');
      expect(entry.key, CoordAreaEntry.coordKey(5, 10));
    });

    test('handles negative coordinates in key', () {
      expect(CoordAreaEntry.coordKey(-3, -7), '-3,-7');
      const entry = CoordAreaEntry(x: -3, y: -7, areaName: 'Negative');
      expect(entry.key, '-3,-7');
    });

    test('handles zero coordinates', () {
      expect(CoordAreaEntry.coordKey(0, 0), '0,0');
    });

    test('audioPath is optional', () {
      const withAudio = CoordAreaEntry(
        x: 0,
        y: 0,
        areaName: 'Test',
        audioPath: 'music.mp3',
      );
      const withoutAudio = CoordAreaEntry(x: 0, y: 0, areaName: 'Test');
      expect(withAudio.audioPath, 'music.mp3');
      expect(withoutAudio.audioPath, isNull);
    });
  });
}
