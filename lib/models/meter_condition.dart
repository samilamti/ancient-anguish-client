import 'vital_colors.dart';

/// Which meter a [MeterCondition] watches.
enum Meter {
  hp('HP'),
  sp('SP');

  const Meter(this.label);

  /// Shown in the trigger editor and rule list.
  final String label;

  /// The band names this meter can be in, in the order the bar shows them
  /// from full to empty. Names, not enum values, because they are what a rule
  /// stores and what a player picks.
  List<String> get bands => switch (this) {
        Meter.hp => [for (final b in HpBand.values) b.name],
        Meter.sp => [for (final b in SpBand.values.reversed) b.name],
      };

  /// The band [value] out of [max] is in.
  String bandOf(int value, int max) => switch (this) {
        Meter.hp => HpBand.forValue(value, max).name,
        Meter.sp => SpBand.forValue(value, max).name,
      };
}

/// Which way the meter must be moving for a [MeterCondition] to fire.
enum MeterDirection {
  either('either way'),
  falling('when dropping'),
  rising('when recovering');

  const MeterDirection(this.label);

  final String label;
}

/// HP and SP at one moment, as the prompt reported them.
class VitalsReading {
  final int hp;
  final int maxHp;
  final int sp;
  final int maxSp;

  const VitalsReading({
    required this.hp,
    required this.maxHp,
    required this.sp,
    required this.maxSp,
  });

  int valueOf(Meter meter) => meter == Meter.hp ? hp : sp;
  int maxOf(Meter meter) => meter == Meter.hp ? maxHp : maxSp;
}

/// A command trigger condition on a meter's colour: "when SP turns cyan",
/// "when HP turns orange while dropping".
///
/// Fires on the change INTO [band], never while the meter merely stays in it,
/// so a trigger that drinks a potion when HP turns orange sends one command
/// per crossing rather than one per prompt. Uses [HpBand] and [SpBand], the
/// same functions that colour the bars, so the trigger and the colour the
/// player sees can't disagree.
class MeterCondition {
  final Meter meter;

  /// A name from [Meter.bands].
  final String band;

  final MeterDirection direction;

  const MeterCondition({
    required this.meter,
    required this.band,
    this.direction = MeterDirection.either,
  });

  /// Whether [band] is one [meter] actually has. A rule loaded with a stale
  /// band name never fires rather than throwing.
  bool get isValid => meter.bands.contains(band);

  /// False for the two combinations that can never happen: dropping into the
  /// full band (nothing is above it) and recovering into the empty one.
  bool get canFire {
    if (!isValid) return false;
    final bands = meter.bands;
    if (direction == MeterDirection.falling && band == bands.first) {
      return false;
    }
    if (direction == MeterDirection.rising && band == bands.last) return false;
    return true;
  }

  /// True when the meter went from another band into [band] between [before]
  /// and [after], moving the way [direction] asks.
  ///
  /// Readings with an unknown max (0) never fire. The state before the first
  /// prompt after connecting has max 0, so without this every trigger on the
  /// band the player logs in with would fire at login.
  bool firesOn(VitalsReading before, VitalsReading after) {
    if (!isValid) return false;
    final beforeMax = before.maxOf(meter);
    final afterMax = after.maxOf(meter);
    if (beforeMax <= 0 || afterMax <= 0) return false;
    final beforeValue = before.valueOf(meter);
    final afterValue = after.valueOf(meter);
    if (meter.bandOf(afterValue, afterMax) != band) return false;
    if (meter.bandOf(beforeValue, beforeMax) == band) return false;

    final beforeFraction = beforeValue / beforeMax;
    final afterFraction = afterValue / afterMax;
    return switch (direction) {
      MeterDirection.either => true,
      MeterDirection.falling => afterFraction < beforeFraction,
      MeterDirection.rising => afterFraction > beforeFraction,
    };
  }

  /// `SP turns cyan`, `HP turns orange when dropping`.
  String get summary {
    final when =
        direction == MeterDirection.either ? '' : ' ${direction.label}';
    return '${meter.label} turns $band$when';
  }

  MeterCondition copyWith({
    Meter? meter,
    String? band,
    MeterDirection? direction,
  }) =>
      MeterCondition(
        meter: meter ?? this.meter,
        band: band ?? this.band,
        direction: direction ?? this.direction,
      );

  Map<String, dynamic> toJson() => {
        'meter': meter.name,
        'band': band,
        'direction': direction.name,
      };

  /// Null when [json] names no known meter.
  static MeterCondition? fromJson(Object? json) {
    if (json is! Map) return null;
    final meter = Meter.values.asNameMap()[json['meter']];
    final band = json['band'];
    if (meter == null || band is! String) return null;
    return MeterCondition(
      meter: meter,
      band: band,
      direction: MeterDirection.values.asNameMap()[json['direction']] ??
          MeterDirection.either,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MeterCondition &&
      other.meter == meter &&
      other.band == band &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(meter, band, direction);
}
