/// Tracks whether the player is currently in combat.
class BattleState {
  final bool inBattle;

  const BattleState({this.inBattle = false});

  BattleState copyWith({bool? inBattle}) {
    return BattleState(inBattle: inBattle ?? this.inBattle);
  }

  static const BattleState initial = BattleState();
}
