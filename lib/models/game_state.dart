/// Parsed game state extracted from the MUD prompt/output.
class GameState {
  /// All recognized directional movement commands (short and long forms).
  static const Set<String> directionalCommands = {
    'n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw',
    'north', 'northeast', 'east', 'southeast',
    'south', 'southwest', 'west', 'northwest',
  };

  // ── Core vitals ──
  final int hp;
  final int maxHp;
  final int sp;
  final int maxSp;
  final int? x;
  final int? y;

  // ── Character identity ──
  final String? playerName;
  final String? playerClass;
  final String? race;
  final int? level;
  final int? age;

  // ── Experience ──
  final int? xp;
  final int? xpPerMin;
  final int? sessionXp;
  final int? sessionXpPerMin;

  // ── Combat ──
  final String? aim;
  final String? attack;
  final String? defend;
  final int? wimpy;
  final String? wimpyDir;

  // ── Wealth ──
  final int? coins;
  final int? banks;

  // ── World ──
  final String? gametime;
  final String? reboot;
  final int? port;

  // ── Survival (donator) ──
  final int? stuffed;
  final int? thirst;
  final int? drunk;
  final int? smoke;
  final int? med;
  final int? encumbered;
  final int? poison;
  final int? alignment;

  // ── Donator vitals ──
  final int? hpPercent;
  final int? spPercent;
  final int? followers;
  final String? following;

  // ── Area detection ──
  final String? currentArea;

  /// Number of directional commands sent while coordinates stayed the same.
  /// Used to detect when the player is in an unmapped indoor area.
  final int directionalMovesAtSameCoords;

  const GameState({
    this.hp = 0,
    this.maxHp = 0,
    this.sp = 0,
    this.maxSp = 0,
    this.x,
    this.y,
    this.playerName,
    this.playerClass,
    this.race,
    this.level,
    this.age,
    this.xp,
    this.xpPerMin,
    this.sessionXp,
    this.sessionXpPerMin,
    this.aim,
    this.attack,
    this.defend,
    this.wimpy,
    this.wimpyDir,
    this.coins,
    this.banks,
    this.gametime,
    this.reboot,
    this.port,
    this.stuffed,
    this.thirst,
    this.drunk,
    this.smoke,
    this.med,
    this.encumbered,
    this.poison,
    this.alignment,
    this.hpPercent,
    this.spPercent,
    this.followers,
    this.following,
    this.currentArea,
    this.directionalMovesAtSameCoords = 0,
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
    String? race,
    int? level,
    int? age,
    int? xp,
    int? xpPerMin,
    int? sessionXp,
    int? sessionXpPerMin,
    String? aim,
    String? attack,
    String? defend,
    int? wimpy,
    String? wimpyDir,
    int? coins,
    int? banks,
    String? gametime,
    String? reboot,
    int? port,
    int? stuffed,
    int? thirst,
    int? drunk,
    int? smoke,
    int? med,
    int? encumbered,
    int? poison,
    int? alignment,
    int? hpPercent,
    int? spPercent,
    int? followers,
    String? following,
    String? currentArea,
    int? directionalMovesAtSameCoords,
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
      race: race ?? this.race,
      level: level ?? this.level,
      age: age ?? this.age,
      xp: xp ?? this.xp,
      xpPerMin: xpPerMin ?? this.xpPerMin,
      sessionXp: sessionXp ?? this.sessionXp,
      sessionXpPerMin: sessionXpPerMin ?? this.sessionXpPerMin,
      aim: aim ?? this.aim,
      attack: attack ?? this.attack,
      defend: defend ?? this.defend,
      wimpy: wimpy ?? this.wimpy,
      wimpyDir: wimpyDir ?? this.wimpyDir,
      coins: coins ?? this.coins,
      banks: banks ?? this.banks,
      gametime: gametime ?? this.gametime,
      reboot: reboot ?? this.reboot,
      port: port ?? this.port,
      stuffed: stuffed ?? this.stuffed,
      thirst: thirst ?? this.thirst,
      drunk: drunk ?? this.drunk,
      smoke: smoke ?? this.smoke,
      med: med ?? this.med,
      encumbered: encumbered ?? this.encumbered,
      poison: poison ?? this.poison,
      alignment: alignment ?? this.alignment,
      hpPercent: hpPercent ?? this.hpPercent,
      spPercent: spPercent ?? this.spPercent,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      currentArea: currentArea ?? this.currentArea,
      directionalMovesAtSameCoords:
          directionalMovesAtSameCoords ?? this.directionalMovesAtSameCoords,
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

  /// Whether combat stats are available.
  bool get hasCombatStats => aim != null || attack != null || defend != null;

  /// Whether survival/condition stats are available.
  bool get hasSurvivalStats =>
      stuffed != null || thirst != null || drunk != null || poison != null;

  /// Whether XP tracking stats are available.
  bool get hasXpTracking => xpPerMin != null || sessionXp != null;

  /// Whether world info is available.
  bool get hasWorldInfo => gametime != null || reboot != null;

  static const GameState initial = GameState();
}
