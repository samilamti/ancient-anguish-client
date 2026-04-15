/// The data type of a prompt element's value, used to build the parsing regex.
enum PromptDataType {
  /// Non-negative integer (e.g. HP, XP, LEVEL). Regex: `(\d+)`
  integer,

  /// Signed integer (e.g. XCOORD, YCOORD). Regex: `(-?\d+)`
  signedInteger,

  /// Single-word string (e.g. NAME, CLASS, RACE). Regex: `(\S+)`
  string,

  /// Percentage integer (e.g. HP%, SP%). Regex: `(\d+)`
  percentage,
}

/// Category groupings for the customization UI.
enum PromptCategory {
  vitals('Vitals', 'Core health and spell points'),
  combat('Combat', 'Aim, attack, and defense stats'),
  experience('Experience', 'XP tracking and session stats'),
  character('Character', 'Identity and progression'),
  world('World', 'Game time and server info'),
  survival('Survival', 'Hunger, thirst, and conditions'),
  wealth('Wealth', 'Coins and bank balances');

  const PromptCategory(this.displayName, this.description);
  final String displayName;
  final String description;
}

/// Unique identifier for each prompt element, in canonical order.
///
/// The enum declaration order determines the position of each element in the
/// `@@...@@` prompt payload. This order must be stable — reordering breaks
/// parsing for users with saved configurations.
enum PromptElementId {
  hp,
  maxHp,
  sp,
  maxSp,
  xCoord,
  yCoord,
  xp,
  xpPerMin,
  sessionXp,
  sessionXpPerMin,
  aim,
  attack,
  defend,
  wimpy,
  wimpyDir,
  coins,
  banks,
  name,
  race,
  playerClass,
  level,
  age,
  gametime,
  reboot,
  port,
  // Donator-only elements.
  stuffed,
  thirst,
  drunk,
  smoke,
  med,
  encumbered,
  poison,
  alignment,
  hpPercent,
  spPercent,
  followers,
  following,
}

/// Metadata for a single prompt element that the MUD can provide.
class PromptElement {
  /// Unique identifier (also determines canonical order).
  final PromptElementId id;

  /// The MUD token used inside `|...|` in the prompt set command.
  final String mudToken;

  /// Human-readable name shown in the customization UI.
  final String displayName;

  /// Short description / tooltip.
  final String description;

  /// UI grouping category.
  final PromptCategory category;

  /// Whether this element requires donator status.
  final bool donatorOnly;

  /// How to parse the value from the prompt payload.
  final PromptDataType dataType;

  /// Core elements cannot be disabled — they are always included.
  final bool isCore;

  const PromptElement({
    required this.id,
    required this.mudToken,
    required this.displayName,
    required this.description,
    required this.category,
    this.donatorOnly = false,
    required this.dataType,
    this.isCore = false,
  });

  /// All available prompt elements in canonical order.
  static const List<PromptElement> allElements = [
    // ── Vitals (core) ──
    PromptElement(
      id: PromptElementId.hp,
      mudToken: 'HP',
      displayName: 'HP',
      description: 'Current hit points',
      category: PromptCategory.vitals,
      dataType: PromptDataType.integer,
      isCore: true,
    ),
    PromptElement(
      id: PromptElementId.maxHp,
      mudToken: 'MAXHP',
      displayName: 'Max HP',
      description: 'Maximum hit points',
      category: PromptCategory.vitals,
      dataType: PromptDataType.integer,
      isCore: true,
    ),
    PromptElement(
      id: PromptElementId.sp,
      mudToken: 'SP',
      displayName: 'SP',
      description: 'Current spell points',
      category: PromptCategory.vitals,
      dataType: PromptDataType.integer,
      isCore: true,
    ),
    PromptElement(
      id: PromptElementId.maxSp,
      mudToken: 'MAXSP',
      displayName: 'Max SP',
      description: 'Maximum spell points',
      category: PromptCategory.vitals,
      dataType: PromptDataType.integer,
      isCore: true,
    ),
    PromptElement(
      id: PromptElementId.xCoord,
      mudToken: 'XCOORD',
      displayName: 'X Coord',
      description: 'Current X coordinate',
      category: PromptCategory.vitals,
      dataType: PromptDataType.signedInteger,
      isCore: true,
    ),
    PromptElement(
      id: PromptElementId.yCoord,
      mudToken: 'YCOORD',
      displayName: 'Y Coord',
      description: 'Current Y coordinate',
      category: PromptCategory.vitals,
      dataType: PromptDataType.signedInteger,
      isCore: true,
    ),

    // ── Vitals (donator) ──
    PromptElement(
      id: PromptElementId.hpPercent,
      mudToken: 'HP%',
      displayName: 'HP %',
      description: 'Hit points as a percentage',
      category: PromptCategory.vitals,
      dataType: PromptDataType.percentage,
      donatorOnly: true,
    ),
    PromptElement(
      id: PromptElementId.spPercent,
      mudToken: 'SP%',
      displayName: 'SP %',
      description: 'Spell points as a percentage',
      category: PromptCategory.vitals,
      dataType: PromptDataType.percentage,
      donatorOnly: true,
    ),

    // ── Experience ──
    PromptElement(
      id: PromptElementId.xp,
      mudToken: 'XP',
      displayName: 'XP',
      description: 'Total experience points',
      category: PromptCategory.experience,
      dataType: PromptDataType.integer,
    ),
    PromptElement(
      id: PromptElementId.xpPerMin,
      mudToken: 'XP/MIN',
      displayName: 'XP/min',
      description: 'Experience per minute over your lifetime',
      category: PromptCategory.experience,
      dataType: PromptDataType.integer,
    ),
    PromptElement(
      id: PromptElementId.sessionXp,
      mudToken: 'SESSIONXP',
      displayName: 'Session XP',
      description: 'Total XP earned this session',
      category: PromptCategory.experience,
      dataType: PromptDataType.integer,
    ),
    PromptElement(
      id: PromptElementId.sessionXpPerMin,
      mudToken: 'SESSIONXP/MIN',
      displayName: 'Session XP/min',
      description: 'XP per minute this session',
      category: PromptCategory.experience,
      dataType: PromptDataType.integer,
    ),

    // ── Combat ──
    PromptElement(
      id: PromptElementId.aim,
      mudToken: 'AIM',
      displayName: 'Aim',
      description: 'Current aim',
      category: PromptCategory.combat,
      dataType: PromptDataType.string,
    ),
    PromptElement(
      id: PromptElementId.attack,
      mudToken: 'ATTACK',
      displayName: 'Attack',
      description: 'Current attack style',
      category: PromptCategory.combat,
      dataType: PromptDataType.string,
    ),
    PromptElement(
      id: PromptElementId.defend,
      mudToken: 'DEFEND',
      displayName: 'Defend',
      description: 'Current defense',
      category: PromptCategory.combat,
      dataType: PromptDataType.string,
    ),
    PromptElement(
      id: PromptElementId.wimpy,
      mudToken: 'WIMPY',
      displayName: 'Wimpy',
      description: 'HP threshold for wimpy flee',
      category: PromptCategory.combat,
      dataType: PromptDataType.integer,
    ),
    PromptElement(
      id: PromptElementId.wimpyDir,
      mudToken: 'WIMPYDIR',
      displayName: 'Wimpy Dir',
      description: 'Direction set for wimpy flee',
      category: PromptCategory.combat,
      dataType: PromptDataType.string,
    ),

    // ── Character ──
    PromptElement(
      id: PromptElementId.name,
      mudToken: 'NAME',
      displayName: 'Name',
      description: 'Your character name',
      category: PromptCategory.character,
      dataType: PromptDataType.string,
    ),
    PromptElement(
      id: PromptElementId.race,
      mudToken: 'RACE',
      displayName: 'Race',
      description: 'Your character race',
      category: PromptCategory.character,
      dataType: PromptDataType.string,
    ),
    PromptElement(
      id: PromptElementId.playerClass,
      mudToken: 'CLASS',
      displayName: 'Class',
      description: 'Your character class',
      category: PromptCategory.character,
      dataType: PromptDataType.string,
    ),
    PromptElement(
      id: PromptElementId.level,
      mudToken: 'LEVEL',
      displayName: 'Level',
      description: 'Character level',
      category: PromptCategory.character,
      dataType: PromptDataType.integer,
    ),
    PromptElement(
      id: PromptElementId.age,
      mudToken: 'AGE',
      displayName: 'Age',
      description: 'Character age',
      category: PromptCategory.character,
      dataType: PromptDataType.integer,
    ),

    // ── Wealth ──
    PromptElement(
      id: PromptElementId.coins,
      mudToken: 'COINS',
      displayName: 'Coins',
      description: 'Total coins on hand',
      category: PromptCategory.wealth,
      dataType: PromptDataType.integer,
    ),
    PromptElement(
      id: PromptElementId.banks,
      mudToken: 'BANKS',
      displayName: 'Banks',
      description: 'Total coins in all your banks',
      category: PromptCategory.wealth,
      dataType: PromptDataType.integer,
    ),

    // ── World ──
    PromptElement(
      id: PromptElementId.gametime,
      mudToken: 'GAMETIME',
      displayName: 'Game Time',
      description: 'The current time on Oerthe',
      category: PromptCategory.world,
      dataType: PromptDataType.string,
    ),
    PromptElement(
      id: PromptElementId.reboot,
      mudToken: 'REBOOT',
      displayName: 'Reboot',
      description: 'Time left until reboot',
      category: PromptCategory.world,
      dataType: PromptDataType.string,
    ),
    PromptElement(
      id: PromptElementId.port,
      mudToken: 'PORT',
      displayName: 'Port',
      description: 'Current connection port',
      category: PromptCategory.world,
      dataType: PromptDataType.integer,
    ),

    // ── Survival (donator only) ──
    PromptElement(
      id: PromptElementId.stuffed,
      mudToken: 'STUFFED',
      displayName: 'Hunger',
      description: 'Current hunger level',
      category: PromptCategory.survival,
      dataType: PromptDataType.integer,
      donatorOnly: true,
    ),
    PromptElement(
      id: PromptElementId.thirst,
      mudToken: 'THIRST',
      displayName: 'Thirst',
      description: 'Current thirst level',
      category: PromptCategory.survival,
      dataType: PromptDataType.integer,
      donatorOnly: true,
    ),
    PromptElement(
      id: PromptElementId.drunk,
      mudToken: 'DRUNK',
      displayName: 'Drunk',
      description: 'Current intoxication level',
      category: PromptCategory.survival,
      dataType: PromptDataType.integer,
      donatorOnly: true,
    ),
    PromptElement(
      id: PromptElementId.smoke,
      mudToken: 'SMOKE',
      displayName: 'Smoke',
      description: 'Currently smoking',
      category: PromptCategory.survival,
      dataType: PromptDataType.integer,
      donatorOnly: true,
    ),
    PromptElement(
      id: PromptElementId.med,
      mudToken: 'MED',
      displayName: 'Bound',
      description: 'Currently bound (meditating)',
      category: PromptCategory.survival,
      dataType: PromptDataType.integer,
      donatorOnly: true,
    ),
    PromptElement(
      id: PromptElementId.encumbered,
      mudToken: 'ENCUMBERED',
      displayName: 'Encumbrance',
      description: 'Current encumbrance level',
      category: PromptCategory.survival,
      dataType: PromptDataType.integer,
      donatorOnly: true,
    ),
    PromptElement(
      id: PromptElementId.poison,
      mudToken: 'POISON',
      displayName: 'Poison',
      description: 'Current poisoning level',
      category: PromptCategory.survival,
      dataType: PromptDataType.integer,
      donatorOnly: true,
    ),
    PromptElement(
      id: PromptElementId.alignment,
      mudToken: 'ALIGNMENT',
      displayName: 'Alignment',
      description: 'Current alignment',
      category: PromptCategory.survival,
      dataType: PromptDataType.signedInteger,
      donatorOnly: true,
    ),
    PromptElement(
      id: PromptElementId.followers,
      mudToken: 'FOLLOWERS',
      displayName: 'Followers',
      description: 'Current followers',
      category: PromptCategory.survival,
      dataType: PromptDataType.integer,
      donatorOnly: true,
    ),
    PromptElement(
      id: PromptElementId.following,
      mudToken: 'FOLLOWING',
      displayName: 'Following',
      description: 'Current leader',
      category: PromptCategory.survival,
      dataType: PromptDataType.string,
      donatorOnly: true,
    ),
  ];

  /// Lookup table by [PromptElementId].
  static final Map<PromptElementId, PromptElement> _byId = {
    for (final e in allElements) e.id: e,
  };

  /// Returns the element definition for the given [id].
  static PromptElement byId(PromptElementId id) => _byId[id]!;

  /// The set of MUD tokens that are always included (core elements).
  static final Set<String> coreTokens = {
    for (final e in allElements)
      if (e.isCore) e.mudToken,
  };
}
