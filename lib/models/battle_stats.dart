import 'battle_filter_mode.dart';
import '../services/parser/battle_text_classifier.dart';

/// Running tallies for the fight currently in progress, plus the most recent
/// combat line — everything the battle HUD needs to stand in for the combat
/// text it replaced under [BattleFilterMode.hud].
///
/// Ancient Anguish prints no damage numbers, so there is nothing to sum. What
/// it *does* print is one line per exchange, which makes hit-versus-miss counts
/// the honest measure of how a fight is going.
class BattleStats {
  /// Whether a fight is currently in progress. Goes false after
  /// `BattleNotifier.battleTimeout` of combat silence.
  final bool active;

  /// The creature most recently named on either side of an exchange.
  final String? target;

  /// Rounds of combat output seen this fight.
  ///
  /// Counted from the *arrival* of combat text — one round per batch of output
  /// the MUD writes — rather than from the `HP:/SP:` line. That line is what
  /// this used to count, and it left the counter frozen at zero through whole
  /// fights: the classifier's vitals pattern is anchored to the whole line (so
  /// a line carrying real content plus vitals is never gagged wholesale), and
  /// under most prompt configurations AA's round vitals never arrive as a line
  /// of their own. Batches are also the honest unit for the HUD, which is
  /// standing in for one screenful of combat text per round.
  final int rounds;

  final int hitsDealt;
  final int missesDealt;
  final int hitsTaken;
  final int missesAgainst;

  /// Exchanges between two parties that are neither the player nor the
  /// player's opponent-of-record — pets, party members, and the target hitting
  /// them back. See [BattleLineKind.otherHit] for why the two can't be told
  /// apart.
  final int otherHits;
  final int otherMisses;

  /// Creatures that died this fight (either side).
  final int resolutions;

  /// HP at the first vitals line of the fight, and the latest reading.
  final int? hpStart;
  final int? hpNow;
  final int? spNow;

  /// The most recent combat line, verbatim. This is what makes the HUD a
  /// replacement for the gagged text rather than just a scoreboard.
  final String? latestLine;

  final DateTime? startedAt;

  const BattleStats({
    this.active = false,
    this.target,
    this.rounds = 0,
    this.hitsDealt = 0,
    this.missesDealt = 0,
    this.hitsTaken = 0,
    this.missesAgainst = 0,
    this.otherHits = 0,
    this.otherMisses = 0,
    this.resolutions = 0,
    this.hpStart,
    this.hpNow,
    this.spNow,
    this.latestLine,
    this.startedAt,
  });

  static const BattleStats initial = BattleStats();

  /// Rounds of combat output that must arrive before a fight counts as real.
  ///
  /// Walking through the world draws the odd swing from a stray NPC, and a
  /// scuffle that is over in a round or two should not flash the HUD up and
  /// shove the terminal's tail out of the way on its way past.
  static const int confirmRounds = 3;

  /// Whether enough rounds have arrived to treat this as a real fight.
  ///
  /// Gates the HUD *and* the gagging that hides combat text behind it — the two
  /// have to move together, or the opening rounds of every fight would be
  /// swallowed by a panel that isn't on screen yet.
  bool get confirmed => rounds >= confirmRounds;

  /// Whether the battle HUD is on screen: a fight both running and confirmed.
  ///
  /// The single definition of "a fight is visibly happening". The HUD dock
  /// keys its fade off it, and so does the battle soundtrack — music that
  /// started on a threshold of its own would strike up for a stray NPC's two
  /// swings, and the player would hear a fight the client never showed them.
  bool get hudVisible => active && confirmed;

  /// Your swings that connected, as a percentage, or `null` before you've
  /// swung at all.
  int? get accuracy {
    final swings = hitsDealt + missesDealt;
    if (swings == 0) return null;
    return (hitsDealt * 100 / swings).round();
  }

  /// Incoming swings you avoided, as a percentage, or `null` before anything
  /// has swung at you.
  int? get evasion {
    final swings = hitsTaken + missesAgainst;
    if (swings == 0) return null;
    return (missesAgainst * 100 / swings).round();
  }

  /// HP lost since the fight's first vitals reading, or `null` when fewer than
  /// two readings have arrived. Negative while healing outpaces damage.
  int? get hpLost {
    if (hpStart == null || hpNow == null) return null;
    return hpStart! - hpNow!;
  }

  /// How long the fight has been running, as of [now].
  Duration? elapsedAt(DateTime now) {
    if (startedAt == null) return null;
    return now.difference(startedAt!);
  }

  BattleStats copyWith({
    bool? active,
    String? target,
    int? rounds,
    int? hitsDealt,
    int? missesDealt,
    int? hitsTaken,
    int? missesAgainst,
    int? otherHits,
    int? otherMisses,
    int? resolutions,
    int? hpStart,
    int? hpNow,
    int? spNow,
    String? latestLine,
    DateTime? startedAt,
  }) {
    return BattleStats(
      active: active ?? this.active,
      target: target ?? this.target,
      rounds: rounds ?? this.rounds,
      hitsDealt: hitsDealt ?? this.hitsDealt,
      missesDealt: missesDealt ?? this.missesDealt,
      hitsTaken: hitsTaken ?? this.hitsTaken,
      missesAgainst: missesAgainst ?? this.missesAgainst,
      otherHits: otherHits ?? this.otherHits,
      otherMisses: otherMisses ?? this.otherMisses,
      resolutions: resolutions ?? this.resolutions,
      hpStart: hpStart ?? this.hpStart,
      hpNow: hpNow ?? this.hpNow,
      spNow: spNow ?? this.spNow,
      latestLine: latestLine ?? this.latestLine,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}
