import 'package:ancient_anguish_client/models/line_spacing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LineSpacing', () {
    test('offers the requested steps and an off position', () {
      expect(
        LineSpacing.values.map((s) => s.percent),
        [0, 25, 33, 50, 75, 100],
      );
    });

    test('round-trips through its storage key', () {
      for (final spacing in LineSpacing.values) {
        expect(LineSpacing.fromStorageKey(spacing.storageKey), spacing);
      }
    });

    test('missing or unparseable keys fall back to off', () {
      expect(LineSpacing.fromStorageKey(null), LineSpacing.none);
      expect(LineSpacing.fromStorageKey('threeQuarters'), LineSpacing.none);
      expect(LineSpacing.fromStorageKey(''), LineSpacing.none);
    });

    test('an unknown percentage snaps to the nearest defined step', () {
      expect(LineSpacing.fromStorageKey('40'), LineSpacing.third);
      expect(LineSpacing.fromStorageKey('60'), LineSpacing.half);
      expect(LineSpacing.fromStorageKey('500'), LineSpacing.full);
    });

    test('extra leading scales with the font size', () {
      expect(LineSpacing.none.extraFor(14), 0);
      expect(LineSpacing.half.extraFor(14), 7);
      expect(LineSpacing.full.extraFor(20), 20);
    });

    test('labels read as percentages, with off spelled out', () {
      expect(LineSpacing.none.label, 'Off');
      expect(LineSpacing.third.label, '33%');
    });
  });
}
