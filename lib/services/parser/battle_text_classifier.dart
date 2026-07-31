/// Shape tests that recognise Ancient Anguish combat spam — the hit, miss,
/// dodge and vitals lines a fight emits several times per second.
///
/// Owned in one place because three consumers must agree on the answers: the
/// terminal buffer (which collapses or gags the lines), the battle HUD's
/// statistics, and battle-mode detection itself. When they disagree the HUD
/// counts a round the terminal already threw away — or worse, the buffer gags
/// a line nothing is showing the player.
///
/// The classifier is deliberately **structural rather than lexical**. AA's
/// damage verbs run to hundreds of entries and gain new ones with every
/// weapon type, but every hit line has the same skeleton:
///
/// ```text
/// <actor> <verb> <owner> <body part>[ <adverb>].
/// ```
///
/// Anatomy is a genuinely closed set, so [bodyParts] anchors the match and
/// the verb is left unconstrained. That is what lets `You skewered Nurse's
/// thigh gruesomely.` classify without anyone having taught it "skewered".
library;

/// What a single line of combat output represents.
enum BattleLineKind {
  /// The round vitals line: `HP:  88  SP:  79`.
  vitals,

  /// You landed a blow: `You pounded Nurse's leg heartlessly.`
  yourHit,

  /// Your attack failed: `You missed.` / `Nurse dodges your attack.`
  yourMiss,

  /// You took a blow: `Nurse pounded your head heartlessly.`
  incomingHit,

  /// An attack on you failed: `Nurse missed you.` /
  /// `You duck your head quickly as Nurse's blow flies over you.`
  incomingMiss,

  /// Somebody else landed a blow: `Mummy pierced Nurse's head keenly.`
  ///
  /// "Somebody else" is honest about the limit here — the classifier can tell
  /// that neither participant is the player, but not which of them is on the
  /// player's side. A pet mauling the target and the target mauling the pet
  /// both land in this bucket.
  otherHit,

  /// Somebody else's attack failed: `Mummy missed Nurse.`
  otherMiss,

  /// A fight resolved: `Nurse died.` / `You killed Nurse.` / `You died.`
  ///
  /// Never filtered out of the terminal — this is the line the player has
  /// been waiting for.
  resolution,
}

/// A classified combat line: what kind it is, who it was against, and the
/// vitals it carried (for [BattleLineKind.vitals] only).
class BattleLineMatch {
  final BattleLineKind kind;

  /// The creature on the other side of the exchange, when the line names one.
  /// `You missed.` names nobody, so this is `null` there.
  final String? opponent;

  final int? hp;
  final int? sp;

  const BattleLineMatch({
    required this.kind,
    this.opponent,
    this.hp,
    this.sp,
  });

  /// Whether this line is combat spam that may be collapsed or gagged.
  /// [BattleLineKind.resolution] is the one kind that always survives.
  bool get isFilterable => kind != BattleLineKind.resolution;

  /// Whether the player is one of the two participants.
  bool get involvesPlayer => switch (kind) {
        BattleLineKind.yourHit ||
        BattleLineKind.yourMiss ||
        BattleLineKind.incomingHit ||
        BattleLineKind.incomingMiss =>
          true,
        _ => false,
      };
}

/// Recognises Ancient Anguish combat lines. All members are static — there is
/// no per-session state, which keeps it trivially unit-testable.
class BattleTextClassifier {
  /// The round vitals line, and *only* that line. Deliberately stricter than
  /// `BattleNotifier.battleLineRegex` (which matches the pattern anywhere in a
  /// line): a line carrying real content plus trailing vitals must not be
  /// gagged wholesale, so the anchors here are the line ends.
  static final RegExp vitalsPattern =
      RegExp(r'^\s*HP:\s+(\d+)\s+SP:\s+(\d+)\s*$');

  /// The shape of an actor: `You`, or a capitalised short description of up to
  /// four words (`Mummy`, `Nurse`, `The city guard`).
  ///
  /// The restrictive character class is what keeps prose out: a tell such as
  /// `Foo tells you: I pounded your head.` fails on the `:` rather than being
  /// read as a hit on the player.
  static const String _actor = r"(?:You|[A-Z][\w'’-]*(?:\s+[\w'’-]+){0,3})";

  /// Whose body part was struck: the player's, or a named creature's.
  static const String _owner = r"(?:your|his|her|its|their|[A-Z][\w'’-]*'s)";

  /// Optional laterality in front of the body part (`left arm`, `hind leg`).
  static const String _side = r'(?:(?:left|right|upper|lower|front|hind|rear|near|far)\s+)?';

  /// `<actor> <verb> <owner> <body part>[ <adverb>].`
  ///
  /// The verb is `[a-z]+` — unconstrained on purpose (see the library doc).
  /// Validity rests on [bodyParts] instead, checked by [classify].
  static final RegExp hitPattern = RegExp(
    '^($_actor)\\s+([a-z]+)\\s+($_owner)\\s+$_side([a-z]+)\\b[^.!?]*[.!]\$',
  );

  /// `You missed.` · `You missed Nurse.` · `Nurse missed you.` ·
  /// `Mummy missed Nurse.`
  static final RegExp missPattern = RegExp(
    '^($_actor)\\s+miss(?:ed|es)?(?:\\s+([^.!?]+?))?\\s*[.!]\$',
  );

  /// A successful evasion by either side. Matched *before* [hitPattern],
  /// because `You duck your head quickly as Nurse's blow flies over you.`
  /// also satisfies the hit skeleton and would otherwise read as a blow
  /// landing on the player.
  static final RegExp defensePattern = RegExp(
    '^($_actor)\\s+'
    '(duck|ducks|dodge|dodges|parry|parries|block|blocks|evade|evades|'
    'sidestep|sidesteps|deflect|deflects|avoid|avoids|dive|dives|'
    'twist|twists|spin|spins|roll|rolls|leap|leaps|jump|jumps|'
    'weave|weaves|fend|fends|ward|wards)\\b([^.!?]*)[.!]\$',
  );

  /// `Nurse died.` · `You killed Nurse.` · `Nurse is dead.` · `You died.`
  static final RegExp resolutionPattern = RegExp(
    '^($_actor)\\s+(?:died|dies|is\\s+dead|'
    'killed|kills|slew|slays|slaughtered|destroyed|'
    'has\\s+been\\s+killed|have\\s+killed|has\\s+killed)'
    '(?:\\s+([^.!?]+?))?\\s*[.!]\$',
  );

  /// Anatomy words that end the noun phrase of a hit line.
  ///
  /// A closed set in a way combat verbs are not — Ancient Anguish's creatures
  /// have tails, wings and tentacles, but the list stops there. Extend it when
  /// output proves a body part is missing; a gap costs one uncollapsed line,
  /// never a wrong classification.
  static const Set<String> bodyParts = {
    // Head and face.
    'head', 'skull', 'face', 'neck', 'throat', 'jaw', 'chin', 'nose', 'snout',
    'muzzle', 'ear', 'ears', 'eye', 'eyes', 'brow', 'temple', 'cheek',
    'mouth', 'tongue', 'scalp',
    // Torso.
    'body', 'torso', 'chest', 'breast', 'ribs', 'ribcage', 'back', 'spine',
    'side', 'flank', 'stomach', 'belly', 'abdomen', 'gut', 'guts', 'waist',
    'groin', 'hip', 'hips', 'shoulder', 'shoulders', 'collarbone',
    // Arms and hands.
    'arm', 'arms', 'elbow', 'forearm', 'wrist', 'hand', 'hands', 'fist',
    'finger', 'fingers', 'thumb', 'knuckles',
    // Legs and feet.
    'leg', 'legs', 'thigh', 'knee', 'shin', 'calf', 'ankle', 'foot', 'feet',
    'heel', 'toe', 'toes', 'shank',
    // Creature anatomy.
    'tail', 'wing', 'wings', 'paw', 'paws', 'claw', 'claws', 'hoof', 'hooves',
    'horn', 'horns', 'tentacle', 'tentacles', 'fin', 'fins', 'hide', 'pelt',
    'carapace', 'scales', 'mane', 'trunk', 'beak', 'talon', 'talons',
    'stinger', 'antenna', 'antennae', 'mandible', 'mandibles',
  };

  /// Words that, standing where the opponent's name should be, mean the line
  /// named the player rather than a creature.
  static const Set<String> _playerWords = {'you', 'your', 'yourself'};

  /// Classifies [plainText], or returns `null` when the line isn't combat
  /// output. [plainText] should be ANSI-stripped and is trimmed here.
  ///
  /// Evaluation order matters and is not arbitrary:
  ///   1. **resolution** — `You killed Nurse.` must never be mistaken for a
  ///      hit, because it is the one line that always reaches the player.
  ///   2. **vitals** — cheap exact shape.
  ///   3. **miss**, then **defense** — both share the hit skeleton.
  ///   4. **hit** — the loosest pattern, so it goes last.
  static BattleLineMatch? classify(String plainText) {
    final line = plainText.trim();
    if (line.isEmpty) return null;

    final resolution = resolutionPattern.firstMatch(line);
    if (resolution != null) {
      return BattleLineMatch(
        kind: BattleLineKind.resolution,
        opponent: _creatureName(resolution.group(2)) ??
            _creatureName(resolution.group(1)),
      );
    }

    final vitals = vitalsPattern.firstMatch(line);
    if (vitals != null) {
      return BattleLineMatch(
        kind: BattleLineKind.vitals,
        hp: int.tryParse(vitals.group(1)!),
        sp: int.tryParse(vitals.group(2)!),
      );
    }

    final miss = missPattern.firstMatch(line);
    if (miss != null) {
      final actor = miss.group(1)!;
      final object = miss.group(2);
      if (_isPlayer(actor)) {
        // `You missed.` / `You missed Nurse.`
        return BattleLineMatch(
          kind: BattleLineKind.yourMiss,
          opponent: _creatureName(object),
        );
      }
      // `Nurse missed you.` → incoming; `Mummy missed Nurse.` → third party.
      final atPlayer = object == null || _isPlayer(object);
      return BattleLineMatch(
        kind: atPlayer ? BattleLineKind.incomingMiss : BattleLineKind.otherMiss,
        opponent: atPlayer ? _creatureName(actor) : _creatureName(object),
      );
    }

    final defense = defensePattern.firstMatch(line);
    if (defense != null) {
      final defender = defense.group(1)!;
      final tail = defense.group(3) ?? '';
      if (_isPlayer(defender)) {
        // You avoided something: the attacker is whoever the tail names.
        return BattleLineMatch(
          kind: BattleLineKind.incomingMiss,
          opponent: _possessiveIn(tail),
        );
      }
      // A creature avoided a blow. If the blow was the player's, that is a
      // miss on the player's ledger; otherwise it belongs to a third party.
      final dodgedPlayer = _mentionsPlayer(tail);
      return BattleLineMatch(
        kind: dodgedPlayer ? BattleLineKind.yourMiss : BattleLineKind.otherMiss,
        opponent: dodgedPlayer
            ? _creatureName(defender)
            : (_possessiveIn(tail) ?? _creatureName(defender)),
      );
    }

    final hit = hitPattern.firstMatch(line);
    if (hit != null) {
      final actor = hit.group(1)!;
      final owner = hit.group(3)!;
      final part = hit.group(4)!;
      if (!bodyParts.contains(part.toLowerCase())) return null;

      final struckPlayer = _isPlayer(owner);
      if (struckPlayer) {
        return BattleLineMatch(
          kind: BattleLineKind.incomingHit,
          opponent: _creatureName(actor),
        );
      }
      return BattleLineMatch(
        kind: _isPlayer(actor)
            ? BattleLineKind.yourHit
            : BattleLineKind.otherHit,
        opponent: _creatureName(owner),
      );
    }

    return null;
  }

  /// Whether [text] refers to the player rather than a creature.
  static bool _isPlayer(String text) =>
      _playerWords.contains(text.trim().toLowerCase());

  /// Whether [text] mentions the player anywhere (`… your attack …`).
  static bool _mentionsPlayer(String text) => RegExp(
        r'\b(you|your|yourself)\b',
        caseSensitive: false,
      ).hasMatch(text);

  /// The first possessive creature name in [text] (`… as Nurse's blow …` →
  /// `Nurse`), or `null` when there isn't one.
  static String? _possessiveIn(String text) {
    final match = RegExp(r"\b([A-Z][\w'’-]*)'s\b").firstMatch(text);
    return match?.group(1);
  }

  /// Normalises a captured name into a bare creature name: strips a possessive
  /// `'s`, drops a leading article, and returns `null` for the player, for
  /// blanks, and for anything that doesn't look like a name.
  static String? _creatureName(String? raw) {
    if (raw == null) return null;
    var name = raw.trim();
    if (name.isEmpty) return null;
    if (name.endsWith("'s") || name.endsWith('’s')) {
      name = name.substring(0, name.length - 2);
    }
    name = name.replaceFirst(RegExp(r'^(?:the|a|an)\s+', caseSensitive: false), '');
    if (name.isEmpty || _isPlayer(name)) return null;
    // A trailing possessive on a multi-word phrase, or stray punctuation, is
    // not a name we can hand to `kill` — better to report nothing.
    if (!RegExp(r"^[\w'’-]+(?:\s+[\w'’-]+){0,3}$").hasMatch(name)) {
      return null;
    }
    return name;
  }
}
