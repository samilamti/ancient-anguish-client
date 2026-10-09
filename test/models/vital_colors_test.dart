import 'dart:ui' show Color;

import 'package:ancient_anguish_client/models/vital_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('spColorFor', () {
    test('white when spent, navy when full', () {
      expect(spColorFor(0, 100), SpBand.white.color);
      expect(spColorFor(100, 100), SpBand.navy.color);
    });

    test('passes exactly through every named stop', () {
      for (final band in SpBand.values) {
        expect(spColorForFraction(band.at), band.color, reason: band.name);
      }
    });

    test('blends between neighbouring stops', () {
      final mid = spColorForFraction(1 / 6);
      expect(mid, Color.lerp(SpBand.white.color, SpBand.cyan.color, 0.5));
    });

    test('darkens monotonically from empty to full', () {
      double luma(Color c) => c.computeLuminance();
      var previous = double.infinity;
      for (var sp = 0; sp <= 90; sp++) {
        final l = luma(spColorFor(sp, 90));
        expect(l, lessThanOrEqualTo(previous + 1e-9), reason: 'sp=$sp');
        previous = l;
      }
    });

    test('clamps over-max and negative values, and an unknown max', () {
      expect(spColorFor(150, 100), SpBand.navy.color);
      expect(spColorFor(-5, 100), SpBand.white.color);
      expect(spColorFor(40, 0), SpBand.white.color);
      expect(spColorForFraction(double.nan), SpBand.white.color);
    });
  });

  group('SpBand', () {
    test('names the nearest stop', () {
      expect(SpBand.forValue(0, 90), SpBand.white);
      expect(SpBand.forValue(14, 90), SpBand.white); // 0.156
      expect(SpBand.forValue(16, 90), SpBand.cyan); // 0.178
      expect(SpBand.forValue(30, 90), SpBand.cyan);
      expect(SpBand.forValue(46, 90), SpBand.blue); // 0.511
      expect(SpBand.forValue(60, 90), SpBand.blue);
      expect(SpBand.forValue(76, 90), SpBand.navy); // 0.844
      expect(SpBand.forValue(90, 90), SpBand.navy);
    });

    test('stops are ordered and span 0..1', () {
      expect(SpBand.values.first.at, 0.0);
      expect(SpBand.values.last.at, 1.0);
      for (var i = 1; i < SpBand.values.length; i++) {
        expect(SpBand.values[i].at, greaterThan(SpBand.values[i - 1].at));
      }
    });
  });

  group('hpColorFor / HpBand', () {
    test('steps at 60%, 30% and 15%', () {
      expect(HpBand.forValue(100, 100), HpBand.green);
      expect(HpBand.forValue(61, 100), HpBand.green);
      expect(HpBand.forValue(60, 100), HpBand.orange);
      expect(HpBand.forValue(31, 100), HpBand.orange);
      expect(HpBand.forValue(30, 100), HpBand.red);
      expect(HpBand.forValue(16, 100), HpBand.red);
      expect(HpBand.forValue(15, 100), HpBand.dying);
      expect(HpBand.forValue(0, 100), HpBand.dying);
    });

    test('colours match the bands', () {
      expect(hpColorFor(90, 100), const Color(0xFF44AA44));
      expect(hpColorFor(50, 100), const Color(0xFFCC8800));
      expect(hpColorFor(20, 100), const Color(0xFFCC2222));
      expect(hpColorFor(10, 100), const Color(0xFFFF1744));
    });

    test('an unknown max reads as dying, over-max as healthy', () {
      expect(HpBand.forValue(50, 0), HpBand.dying);
      expect(HpBand.forValue(200, 100), HpBand.green);
    });
  });
}
