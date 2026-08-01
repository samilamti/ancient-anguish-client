import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/health_tempo.dart';

void main() {
  group('thresholds', () {
    test('full health is the track as recorded', () {
      expect(HealthTempo.forFraction(1.0), HealthTempo.calm);
      expect(HealthTempo.forFraction(0.80), HealthTempo.calm);
      expect(HealthTempo.calm.speed, 1.0);
    });

    test('each step is entered on dropping below its threshold', () {
      expect(HealthTempo.forFraction(0.74), HealthTempo.pressed);
      expect(HealthTempo.forFraction(0.49), HealthTempo.urgent);
      expect(HealthTempo.forFraction(0.32), HealthTempo.desperate);
      expect(HealthTempo.forFraction(0.0), HealthTempo.desperate);
    });

    test('exactly on a threshold is still the calmer step', () {
      // "below 75%", not "at or below". Read from calm, so the answer is the
      // threshold alone and not the hysteresis exercised further down.
      expect(HealthTempo.forFraction(0.75), HealthTempo.calm);
      expect(HealthTempo.forFraction(0.50), HealthTempo.pressed);
      expect(HealthTempo.forFraction(0.33), HealthTempo.urgent);
    });

    test('the steps get faster, and stay within reason', () {
      final speeds = HealthTempo.values.map((t) => t.speed).toList();
      for (var i = 1; i < speeds.length; i++) {
        expect(speeds[i], greaterThan(speeds[i - 1]));
      }
      // Past ~1.5x a soundtrack stops sounding tense and starts sounding
      // comic, which is the opposite of the point.
      expect(speeds.last, lessThanOrEqualTo(1.5));
    });
  });

  group('hysteresis', () {
    test('escalation is immediate', () {
      expect(
        HealthTempo.forFraction(0.30, current: HealthTempo.calm),
        HealthTempo.desperate,
      );
    });

    test('a fraction hovering just above a threshold holds its step', () {
      // Trading blows with something evenly matched parks HP right here, and
      // a rate flipping every round is worse than one that never moved.
      expect(
        HealthTempo.forFraction(0.76, current: HealthTempo.pressed),
        HealthTempo.pressed,
      );
      expect(
        HealthTempo.forFraction(0.52, current: HealthTempo.urgent),
        HealthTempo.urgent,
      );
    });

    test('clearing the margin steps back down', () {
      expect(
        HealthTempo.forFraction(0.79, current: HealthTempo.pressed),
        HealthTempo.calm,
      );
    });

    test('healing past several thresholds drops straight through', () {
      expect(
        HealthTempo.forFraction(0.95, current: HealthTempo.desperate),
        HealthTempo.calm,
      );
    });
  });
}
