/// Parsed game state extracted from the MUD prompt/output.
class GameState {
  final int hp;
  final int maxHp;
  final int sp;
  final int maxSp;
  final int? x;
  final int? y;
  final String? playerName;
  final String? playerClass;
  final int? coins;
  final int? xp;
  final String? currentArea;

  /// Number of commands sent since the last coordinate change.
  /// Used to detect when the player has settled at unmapped coordinates.
  final int commandsSinceCoordChange;

  const GameState({
    this.hp = 0,
    this.maxHp = 0,
    this.sp = 0,
    this.maxSp = 0,
    this.x,
    this.y,
    this.playerName,
    this.playerClass,
    this.coins,
    this.xp,
    this.currentArea,
    this.commandsSinceCoordChange = 0,
  });

  /// Creates a copy with updated fields.
  GameState copyWith({
    int? hp,
    int? maxHp,
    int? sp,
    int? maxSp,
    int? x,
    int? y,
    String? playerName,
    String? playerClass,
    int? coins,
    int? xp,
    String? currentArea,
    int? commandsSinceCoordChange,
  }) {
    return GameState(
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      sp: sp ?? this.sp,
      maxSp: maxSp ?? this.maxSp,
      x: x ?? this.x,
      y: y ?? this.y,
      playerName: playerName ?? this.playerName,
      playerClass: playerClass ?? this.playerClass,
      coins: coins ?? this.coins,
      xp: xp ?? this.xp,
      currentArea: currentArea ?? this.currentArea,
      commandsSinceCoordChange:
          commandsSinceCoordChange ?? this.commandsSinceCoordChange,
    );
  }

  /// HP as a fraction (0.0 – 1.0).
  double get hpFraction => maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;

  /// SP as a fraction (0.0 – 1.0).
  double get spFraction => maxSp > 0 ? (sp / maxSp).clamp(0.0, 1.0) : 0.0;

  /// Whether we have valid vitals data.
  bool get hasVitals => maxHp > 0;

  /// Whether we have coordinate data.
  bool get hasCoordinates => x != null && y != null;

  static const GameState initial = GameState();
}
