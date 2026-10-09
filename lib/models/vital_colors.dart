import 'dart:ui' show Color;

/// The colours of the HP and SP meters, as pure functions of the numbers.
///
/// Kept out of the widgets on purpose: a meter's colour is a fact about the
/// character, not about how one bar happens to paint it, and anything else
/// that wants to react to "SP has gone cyan" (a trigger condition, say) must
/// agree with the bar exactly. So the bar asks these functions, and so will
/// everything else.

/// A named point on the SP gradient, from empty to full.
///
/// The bar runs smoothly through these hues — white when spent, navy when
/// full — and [SpBand.forValue] names the stop the current colour is closest
/// to, so "SP turned cyan" means the same thing as the colour you can see.
enum SpBand {
  /// Spent: 0 SP.
  white(at: 0.0, color: Color(0xFFFFFFFF)),

  /// Running low: around a third.
  cyan(at: 1 / 3, color: Color(0xFF3FD8F0)),

  /// Comfortable: around two thirds.
  blue(at: 2 / 3, color: Color(0xFF2E6BFF)),

  /// Full. A touch lighter than web `navy` (#000080), which disappears into
  /// the meter's near-black track; the fill also carries an outline.
  navy(at: 1.0, color: Color(0xFF1A2E8C));

  const SpBand({required this.at, required this.color});

  /// Where on the 0..1 SP fraction this hue sits exactly.
  final double at;

  /// The hue at [at].
  final Color color;

  /// The band whose stop is nearest [fraction] (0..1, clamped).
  static SpBand forFraction(double fraction) {
    final f = _clamp(fraction);
    var best = SpBand.white;
    for (final band in SpBand.values) {
      if ((band.at - f).abs() <= (best.at - f).abs()) best = band;
    }
    return best;
  }

  /// The band for [sp] out of [maxSp]; an unknown max reads as spent.
  static SpBand forValue(int sp, int maxSp) =>
      forFraction(_fraction(sp, maxSp));
}

/// The SP meter colour: a smooth gradient through the [SpBand] stops,
/// white at 0 SP to navy at [maxSp].
Color spColorFor(int sp, int maxSp) => spColorForFraction(_fraction(sp, maxSp));

/// [spColorFor] for a fraction already computed (0..1, clamped).
Color spColorForFraction(double fraction) {
  final f = _clamp(fraction);
  const stops = SpBand.values;
  for (var i = 1; i < stops.length; i++) {
    final lo = stops[i - 1];
    final hi = stops[i];
    if (f <= hi.at) {
      final t = (f - lo.at) / (hi.at - lo.at);
      return Color.lerp(lo.color, hi.color, t)!;
    }
  }
  return stops.last.color;
}

/// The HP meter's colour steps. Discrete rather than a gradient: a sudden
/// change from green to orange is noticed mid-fight, a slow drift is not.
enum HpBand {
  /// Above 60%.
  green(above: 0.6, color: Color(0xFF44AA44)),

  /// Above 30%.
  orange(above: 0.3, color: Color(0xFFCC8800)),

  /// 30% and below (including an unknown max).
  red(above: double.negativeInfinity, color: Color(0xFFCC2222));

  const HpBand({required this.above, required this.color});

  /// The band applies while the HP fraction is strictly above this.
  final double above;

  /// The meter colour for this band.
  final Color color;

  /// The band for [fraction] (0..1, clamped).
  static HpBand forFraction(double fraction) {
    final f = _clamp(fraction);
    return HpBand.values.firstWhere((b) => f > b.above);
  }

  /// The band for [hp] out of [maxHp]; an unknown max reads as critical.
  static HpBand forValue(int hp, int maxHp) =>
      forFraction(_fraction(hp, maxHp));
}

/// The HP meter colour for [hp] out of [maxHp].
Color hpColorFor(int hp, int maxHp) => HpBand.forValue(hp, maxHp).color;

double _fraction(int value, int max) => max > 0 ? value / max : 0.0;

double _clamp(double f) => f.isNaN ? 0.0 : f.clamp(0.0, 1.0);
