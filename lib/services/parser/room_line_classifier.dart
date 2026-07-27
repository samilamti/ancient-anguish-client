/// Shape tests for a single line of MUD output — room headers, prompt lines,
/// and "there is a creature standing here" NPC lines.
///
/// Owned in one place because two consumers must agree on the answers: the
/// Kill picker's room-target detector (`RoomTargetsNotifier`) and the
/// kill-target link processor that renders those targets tappable. When they
/// disagree, the terminal offers a `kill` link for something the picker would
/// never list — or vice versa.
class RoomLineClassifier {
  /// `Room Name (n,e,sw)` — the header that opens a room block.
  static final RegExp roomHeaderPattern = RegExp(
    r'^[A-Z][^()\n]*\(([nsewud]{1,2}(,\s*[nsewud]{1,2})*)\)\s*$',
  );

  /// A bracketed status/prompt line, which closes a room block.
  static final RegExp promptShapePattern = RegExp(r'^[<\[].*[>\]]\s*$');

  /// `A|An|The|Some <up to five words>` with an *optional* trailing period —
  /// the shape of a line announcing a thing present in the room. Ancient
  /// Anguish prints most short descriptions bare (`A forest Hare`), so
  /// requiring the period missed the majority of real room listings.
  ///
  /// Shape alone doesn't make it a creature; see [npcKeywordIn].
  static final RegExp npcLinePattern = RegExp(
    r'^(A|An|The|Some)\s+\S+(\s+\S+){0,4}\.?\s*$',
  );

  /// Words that almost always indicate a description line ("The grass is
  /// damp.", "The path leads east.") rather than a discrete NPC.
  static final RegExp descriptionGiveaway = RegExp(
    r'\b(is|are|was|were|has|have|had|leads|goes|stands|sits|lies|hangs|smells|seems|appears|here|there)\b',
    caseSensitive: false,
  );

  /// Function words that belong to a *sentence*, never to the bare noun
  /// phrase of a short description. Checked against every word after the
  /// leading article, which is what keeps the now-looser [npcLinePattern]
  /// from reading prose as an announcement: `A wolf howls in the distance`
  /// is rejected on `in`/`the` rather than offering `kill distance`.
  static const Set<String> sentenceFunctionWords = {
    'a', 'an', 'the', 'of', 'in', 'into', 'on', 'onto', 'at', 'to', 'from',
    'with', 'without', 'by', 'for', 'about', 'over', 'under', 'behind',
    'beside', 'between', 'through', 'toward', 'towards', 'against', 'across',
    'along', 'around', 'near', 'off', 'out', 'and', 'or', 'but', 'as', 'than',
    'his', 'her', 'its', 'their', 'your', 'my', 'our', 'this', 'that',
    'these', 'those', 'who', 'which', 'what',
  };

  /// Verbs that end a short MUD sentence sharing the announcement shape
  /// (`A goblin arrives`, `The troll roars`). Without this the last word of
  /// such a line becomes the keyword and the terminal offers `kill arrives`.
  ///
  /// Like [nonTargetNouns] this is deliberately over-inclusive — no creature
  /// in Ancient Anguish is named after a third-person verb, so a false entry
  /// costs nothing.
  static const Set<String> nonTargetVerbs = {
    // Arriving and leaving.
    'arrives', 'leaves', 'enters', 'departs', 'returns', 'comes', 'flees',
    'follows', 'wanders', 'charges', 'retreats', 'advances', 'approaches',
    'vanishes', 'disappears', 'appears', 'materializes', 'materialises',
    // Moving.
    'moves', 'walks', 'runs', 'flies', 'swims', 'crawls', 'climbs', 'jumps',
    'falls', 'stumbles', 'staggers', 'circles', 'paces', 'turns', 'stops',
    'starts', 'rises', 'lands', 'drops', 'dies',
    // Noises.
    'growls', 'roars', 'snarls', 'howls', 'hisses', 'spits', 'barks',
    'screams', 'screeches', 'shrieks', 'squeaks', 'chirps', 'bleats',
    'grunts', 'snorts', 'sniffs', 'groans', 'coughs', 'sneezes', 'yawns',
    'laughs', 'giggles', 'chuckles', 'cries', 'weeps', 'sobs', 'shouts',
    'yells', 'mutters', 'mumbles', 'whispers', 'speaks', 'talks', 'sings',
    'chants', 'prays',
    // Gestures and idling.
    'nods', 'smiles', 'frowns', 'grins', 'waves', 'bows', 'points', 'shrugs',
    'blinks', 'stares', 'glares', 'watches', 'looks', 'listens', 'waits',
    'rests', 'sleeps', 'wakes', 'breathes', 'shivers', 'trembles', 'twitches',
    'eats', 'drinks', 'sits', 'stands', 'lies',
    // Combat.
    'attacks', 'strikes', 'hits', 'misses', 'swings', 'lunges', 'dodges',
    'blocks', 'parries', 'casts', 'heals', 'kills', 'bites', 'claws', 'kicks',
    'punches', 'stabs', 'slashes',
    // Miscellaneous.
    'opens', 'closes', 'breaks', 'shatters', 'burns', 'glows', 'flickers',
    'fades', 'shimmers', 'shudders', 'obeys', 'agrees', 'refuses',
    'hesitates', 'searches', 'takes', 'gives', 'picks', 'wears', 'wields',
  };

  /// Head nouns that are scenery, furniture, or grammar — never something you
  /// can attack. Applied to the *extracted keyword only*, so a creature whose
  /// name merely contains one of these ("A stone golem." → `golem`) is
  /// unaffected.
  ///
  /// The list is deliberately over-inclusive: a missed target costs the player
  /// one tap in the Kill picker, whereas a wrong one puts a red `kill door`
  /// link in the middle of their screen. Extend it whenever output proves a
  /// noun isn't attackable.
  static const Set<String> nonTargetNouns = {
    // Doors, portals, and other openings.
    'door', 'doors', 'gate', 'gates', 'portal', 'portals', 'entrance', 'exit',
    'exits', 'archway', 'arch', 'hatch', 'trapdoor', 'window', 'windows',
    // Signage and readables.
    'sign', 'signs', 'signpost', 'signposts', 'post', 'pole', 'board',
    'boards', 'notice', 'plaque', 'poster', 'placard', 'scroll', 'note',
    'letter', 'map', 'book', 'tome', 'banner', 'flag',
    // Containers and furniture.
    'urn', 'urns', 'chest', 'chests', 'box', 'crate', 'barrel', 'sack', 'bag',
    'pouch', 'table', 'tables', 'chair', 'chairs', 'bench', 'stool', 'bed',
    'desk', 'shelf', 'shelves', 'cabinet', 'altar', 'statue', 'fountain',
    'well', 'pool', 'pillar', 'column', 'throne', 'cauldron', 'brazier',
    'torch', 'lantern', 'lamp', 'candle', 'mirror', 'painting', 'tapestry',
    'rug', 'carpet', 'ladder', 'stairs', 'staircase', 'steps', 'bridge',
    'rope', 'chain', 'lever', 'button', 'switch', 'bucket', 'trough',
    'anvil', 'forge', 'furnace', 'cart', 'wagon', 'boat', 'raft', 'ship',
    // What's left of something already killed.
    'corpse', 'corpses', 'body', 'remains', 'carcass', 'bones', 'skull',
    'grave', 'tombstone', 'gravestone',
    // Terrain and weather.
    'path', 'paths', 'road', 'roads', 'trail', 'track', 'wall', 'walls',
    'floor', 'ceiling', 'roof', 'ground', 'grass', 'tree', 'trees', 'bush',
    'bushes', 'rock', 'rocks', 'boulder', 'stone', 'stones', 'river',
    'stream', 'water', 'sand', 'snow', 'ice', 'fire', 'smoke', 'mist', 'fog',
    'air', 'sky', 'sun', 'moon', 'light', 'darkness', 'shadow', 'shadows',
    'clearing', 'cave', 'tunnel', 'hill', 'slope', 'forest', 'pit', 'hole',
    'ledge', 'cliff', 'waterfall', 'pond', 'lake', 'sea', 'ocean', 'beach',
    'shore', 'field', 'meadow', 'garden', 'hedge', 'fence', 'flowers',
    'moss', 'vines', 'roots', 'branch', 'log', 'stump', 'leaves', 'dirt',
    'mud', 'dust', 'ash', 'gravel', 'pebbles',
    // Directions.
    'north', 'south', 'east', 'west', 'northeast', 'northwest', 'southeast',
    'southwest', 'up', 'down', 'inside', 'outside',
    // Grammar words a naive "last word" grab picks up.
    'you', 'me', 'him', 'her', 'it', 'them', 'us', 'someone', 'something',
    'nothing', 'everything', 'anything', 'all', 'one', 'way', 'place',
    'area', 'room', 'corner', 'side', 'end', 'top', 'bottom', 'middle',
    'edge', 'center', 'centre',
  };

  static bool isRoomHeader(String line) =>
      roomHeaderPattern.hasMatch(line.trimRight());

  static bool isPromptShape(String line) =>
      promptShapePattern.hasMatch(line.trimRight());

  /// The attackable keyword announced by [line], or `null` when the line
  /// isn't an NPC announcement (wrong shape, a description, a sentence, or a
  /// head noun in [nonTargetNouns]).
  ///
  /// The keyword is the head noun — the last word of the noun phrase —
  /// lowercased so it can be appended to `kill ` directly. Any number of
  /// adjectives in front of it is fine, and the trailing period is optional,
  /// so all three of Ancient Anguish's usual shapes resolve:
  /// `A forest Hare` → `hare`, `A giant eagle.` → `eagle`,
  /// `An ugly-looking fierce Troll` → `troll`.
  ///
  /// Callers are responsible for the room-block gate: this is a pure shape
  /// test, and plenty of combat text shares the shape.
  static String? npcKeywordIn(String line) {
    final trimmed = line.trimRight();
    if (!npcLinePattern.hasMatch(trimmed)) return null;
    if (descriptionGiveaway.hasMatch(trimmed)) return null;

    var s = trimmed.trim();
    final paren = s.indexOf('(');
    if (paren > 0) s = s.substring(0, paren).trimRight();
    if (s.isEmpty) return null;

    final words = s.split(RegExp(r'\s+')).map(_bareWord).toList()
      ..removeWhere((w) => w.isEmpty);
    if (words.length < 2) return null;

    // Everything after the article must be an adjective or the noun itself.
    // A function word means this is a sentence, not a room listing.
    for (final w in words.skip(1)) {
      if (sentenceFunctionWords.contains(w)) return null;
    }

    final keyword = words.last;
    if (nonTargetNouns.contains(keyword)) return null;
    if (nonTargetVerbs.contains(keyword)) return null;
    // An adverb ends a sentence, never a noun phrase ("swings wildly"). No
    // Ancient Anguish creature is named `-ly`, so the suffix is safe to drop
    // wholesale rather than enumerated like [nonTargetVerbs].
    if (keyword.length > 3 && keyword.endsWith('ly')) return null;
    return keyword;
  }

  /// Lowercases [word] and strips the punctuation that surrounds it in prose
  /// (`Hare.` → `hare`, `tall,` → `tall`), keeping interior hyphens and
  /// apostrophes so `ugly-looking` and `wolf's` stay intact.
  static String _bareWord(String word) => word
      .toLowerCase()
      .replaceAll(RegExp(r"^[^a-z0-9]+"), '')
      .replaceAll(RegExp(r"[^a-z0-9]+$"), '');
}
