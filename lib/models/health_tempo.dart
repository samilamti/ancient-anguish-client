/// How fast the soundtrack plays, as a function of how badly the fight is
/// going.
///
/// Ancient Anguish tells you your HP in a number on a prompt line, which is
/// exactly the thing a player stops reading once the screen is moving. The
/// music is already playing, so speeding it up puts the same information
/// somewhere that needs no attention at all — a track that is noticeably
/// hurrying is a wound you feel before you have read anything.
///
/// Three steps rather than a continuous ramp: a smoothly-varying rate reads as
/// a wobbly recording rather than as a signal, whereas a discrete change is
/// heard as an event. The rates are deliberately modest — playback speed on
/// both backends resamples, so it carries pitch with it, and past ~1.5x a
/// soundtrack stops sounding tense and starts sounding comic.
enum HealthTempo {
  /// Above 75% — the track as recorded.
  calm(threshold: 1.01, speed: 1.0),

  /// Below 75%.
  pressed(threshold: 0.75, speed: 1.10),

  /// Below 50%.
  urgent(threshold: 0.50, speed: 1.25),

  /// Below 33%.
  desperate(threshold: 0.33, speed: 1.45);

  const HealthTempo({required this.threshold, required this.speed});

  /// Entered when the HP fraction drops *below* this.
  final double threshold;

  /// Playback rate, 1.0 being the track's own speed.
  final double speed;

  /// How far back above a threshold the player must heal before the tempo
  /// steps down again.
  ///
  /// Without it, HP sitting on a boundary — which is precisely where it sits
  /// while you trade blows with something evenly matched — flips the rate on
  /// every round, and a soundtrack that lurches between two speeds is worse
  /// than one that never changed.
  static const double releaseMargin = 0.03;

  /// The tempo for [hpFraction] (0..1), given the tempo already playing.
  ///
  /// Escalation is immediate; de-escalation waits for [releaseMargin].
  static HealthTempo forFraction(
    double hpFraction, {
    HealthTempo current = HealthTempo.calm,
  }) {
    var next = HealthTempo.calm;
    for (final tempo in HealthTempo.values) {
      if (hpFraction < tempo.threshold) next = tempo;
    }
    final easing = next.index < current.index;
    if (easing && hpFraction < current.threshold + releaseMargin) {
      return current;
    }
    return next;
  }
}
