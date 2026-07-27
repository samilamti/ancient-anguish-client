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

  /// `A|An|The|Some <up to four words>.` — the shape of a line announcing a
  /// thing present in the room. Shape alone doesn't make it a creature; see
  /// [npcKeywordIn].
  static final RegExp npcLinePattern = RegExp(
    r'^(A|An|The|Some)\s+\S+(\s+\S+){0,3}\.\s*$',
  );

  /// Words that almost always indicate a description line ("The grass is
  /// damp.", "The path leads east.") rather than a discrete NPC.
  static final RegExp descriptionGiveaway = RegExp(
    r'\b(is|are|was|were|has|have|had|leads|goes|stands|sits|lies|hangs|smells|seems|appears|here|there)\b',
    caseSensitive: false,
  );

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
  /// isn't an NPC announcement (wrong shape, a description, or a head noun
  /// in [nonTargetNouns]).
  ///
  /// The keyword is the last word before the closing period, lowercased so it
  /// can be appended to `kill ` directly — `A Goblin Warrior.` → `warrior`,
  /// `A giant eagle.` → `eagle` (not the adjective).
  ///
  /// Callers are responsible for the room-block gate: this is a pure shape
  /// test, and plenty of combat text ("The giant orc snarls.") shares the
  /// shape while its last word is a verb.
  static String? npcKeywordIn(String line) {
    final trimmed = line.trimRight();
    if (!npcLinePattern.hasMatch(trimmed)) return null;
    if (descriptionGiveaway.hasMatch(trimmed)) return null;

    var s = trimmed.trim();
    final paren = s.indexOf('(');
    if (paren > 0) s = s.substring(0, paren).trimRight();
    if (s.endsWith('.')) s = s.substring(0, s.length - 1).trimRight();
    if (s.isEmpty) return null;

    final words = s.split(RegExp(r'\s+'));
    if (words.length < 2) return null;

    final keyword = words.last.toLowerCase();
    if (nonTargetNouns.contains(keyword)) return null;
    return keyword;
  }
}
