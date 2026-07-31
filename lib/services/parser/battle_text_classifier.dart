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

  /// Combat chatter that scores nothing: `Ship rat predicts your attempt to
  /// dodge!`
  ///
  /// It is unmistakably part of the fight, so it must be filterable — but it
  /// reports neither a hit nor a successful evasion, and counting it as either
  /// would put a number in the HUD that never happened. A separate kind keeps
  /// it out of the terminal without touching the tallies.
  flavour,
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
  ///
  /// The trailing words are **lazy** (`{0,3}?`): every pattern here follows the
  /// actor with a required verb, so the shortest name that still lets the verb
  /// match is the right one. Greedy matching read `Ship rat is vanquished.` as
  /// actor `Ship rat is` plus verb `vanquished` — a plausible-looking opponent
  /// name with a stray word welded on, which then reaches the HUD and `kill`.
  static const String _actor = r"(?:You|[A-Z][\w'’-]*(?:\s+[\w'’-]+){0,3}?)";

  /// A possessive: the player's, or a named creature's. Used for whose body
  /// part was struck (`Nurse's leg`) and whose attempt was read
  /// (`Ship rat's attack`).
  ///
  /// The creature name must allow **several words** before the possessive.
  /// Ancient Anguish is full of two-word short descriptions (`Ship rat`,
  /// `city guard`, `forest hare`), and a single-word-only possessive silently
  /// classified none of their hit lines — every `You slit Ship rat's body.`
  /// reached the terminal unfiltered while `You slit Nurse's body.` collapsed.
  /// The symptom is per-creature, which is what makes it easy to miss.
  static const String _possessive =
      r"(?:your|his|her|its|their|[A-Z][\w'’-]*(?:\s+[\w'’-]+){0,3}'s)";

  /// Optional laterality in front of the body part (`left arm`, `hind leg`).
  static const String _side = r'(?:(?:left|right|upper|lower|front|hind|rear|near|far)\s+)?';

  /// `<actor> <verb> <owner> <body part>[ <adverb>].`
  ///
  /// The verb is `[a-z]+` — unconstrained on purpose (see the library doc).
  /// Validity rests on [bodyParts] instead, checked by [classify].
  static final RegExp hitPattern = RegExp(
    '^($_actor)\\s+([a-z]+)\\s+($_possessive)\\s+$_side([a-z]+)\\b[^.!?]*[.!]\$',
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

  /// A footwork evasion, which AA phrases as a *movement* rather than a dodge
  /// verb: `You take a quick step backwards, avoiding Ship rat's attack.`
  ///
  /// Kept separate from [defensePattern] because the defender's action here is
  /// `take`/`make`, which is far too common a verb to add to that alternation —
  /// the load-bearing part is the trailing `avoiding <someone>'s attack`, so
  /// that is what this anchors on.
  static final RegExp footworkPattern = RegExp(
    '^($_actor)\\s+(?:takes?|made?|makes)\\s+[^.!?]*?'
    '\\b(?:avoiding|evading|dodging|escaping)\\s+([^.!?]+?)\\s*[.!]\$',
  );

  /// Combat chatter that scores nothing: `Ship rat predicts your attempt to
  /// dodge!`
  ///
  /// Anchored on the *idiom* rather than a verb list, since the point is that
  /// no exchange is being reported — see [BattleLineKind.flavour].
  static final RegExp flavourPattern = RegExp(
    '^($_actor)\\s+(?:predicts?|anticipates?|foresees?|reads?)\\s+'
    '$_possessive\\s+attempts?\\s+to\\s+[a-z]+[^.!?]*[.!]\$',
  );

  /// `Nurse died.` · `You killed Nurse.` · `Nurse is dead.` · `You died.` ·
  /// `Ship rat is vanquished.` · `You vanquished Ship rat.`
  ///
  /// The `is <past participle>` branch carries the passive phrasings AA uses
  /// for a death it reports from the victim's side.
  static final RegExp resolutionPattern = RegExp(
    '^($_actor)\\s+(?:died|dies|'
    'is\\s+(?:dead|vanquished|slain|destroyed|killed)|'
    'killed|kills|slew|slays|slaughtered|destroyed|vanquished|vanquishes|'
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
  ///   3. **miss**, then **defense**, **footwork** and **flavour** — all four
  ///      share the hit skeleton (`You take a quick step backwards, avoiding
  ///      Ship rat's attack.` reads as actor + verb + possessive + noun).
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

    final footwork = footworkPattern.firstMatch(line);
    if (footwork != null) {
      final defender = footwork.group(1)!;
      // `avoiding Ship rat's attack` — the attacker is the possessive here,
      // not the defender.
      final attacker = _possessiveIn(footwork.group(2) ?? '');
      if (_isPlayer(defender)) {
        return BattleLineMatch(
          kind: BattleLineKind.incomingMiss,
          opponent: attacker,
        );
      }
      // A creature side-stepped. Whose blow it dodged decides the ledger, the
      // same way [defensePattern] does it.
      final dodgedPlayer = _mentionsPlayer(footwork.group(2) ?? '');
      return BattleLineMatch(
        kind: dodgedPlayer ? BattleLineKind.yourMiss : BattleLineKind.otherMiss,
        opponent: dodgedPlayer ? _creatureName(defender) : attacker,
      );
    }

    if (flavourPattern.hasMatch(line)) {
      // No exchange reported, so no opponent is claimed either — the target
      // shown in the HUD should keep whatever the real exchanges established.
      return const BattleLineMatch(kind: BattleLineKind.flavour);
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
  /// `Nurse`, `… avoiding Ship rat's attack` → `Ship rat`), or `null` when
  /// there isn't one. Multi-word for the same reason [_possessive] is.
  static String? _possessiveIn(String text) {
    final match =
        RegExp(r"\b([A-Z][\w'’-]*(?:\s+[\w'’-]+){0,3})'s\b").firstMatch(text);
    return _creatureName(match?.group(1));
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
