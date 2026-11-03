import '../services/parser/room_line_classifier.dart';

/// What a room listing put in front of the player.
enum RoomEntityKind {
  /// A creature: look at it, kill it.
  npc('NPC'),

  /// Food and drink: pick it up, eat or drink it.
  edible('Edible'),

  /// Gear and loot that can be carried and sold: weapons, armour, coins.
  item('Item'),

  /// Anything else, usually fixed in place or unique to one room: look at it.
  misc('Misc');

  final String label;
  const RoomEntityKind(this.label);

  static RoomEntityKind? fromName(String? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// One thing a room block listed, with the commands the Room Insight panel
/// offers for it.
class RoomEntity {
  final RoomEntityKind kind;

  /// What the parser decided before any player override.
  final RoomEntityKind autoKind;

  /// What the panel calls it: the keyword (`frog`, `frog 2`), or for a counted
  /// pile the whole phrase (`gold coins`).
  final String label;

  /// The word the MUD understands, with Ancient Anguish's ordinal on a
  /// duplicate (`frog 2`), so it can be appended to a command as-is.
  final String keyword;

  /// The head noun without its ordinal (`frog`).
  final String base;

  /// The whole noun phrase, lowercased and without article, count or
  /// trailing period (`wasps nest`). The key a player's recategorisation is
  /// stored under, so it applies to this thing and not to every nest.
  final String phrase;

  /// The number a counted listing led with (`29 gold coins.` → 29).
  final int? count;

  /// The room line this came from, verbatim.
  final String line;

  final List<String> commands;

  const RoomEntity({
    required this.kind,
    required this.autoKind,
    required this.label,
    required this.keyword,
    required this.base,
    required this.phrase,
    required this.line,
    required this.commands,
    this.count,
  });

  bool get isOverridden => kind != autoKind;

  /// This entity as [newKind], with that kind's commands.
  RoomEntity withKind(RoomEntityKind newKind) => RoomEntity(
        kind: newKind,
        autoKind: autoKind,
        label: label,
        keyword: keyword,
        base: base,
        phrase: phrase,
        line: line,
        count: count,
        commands: RoomInsightParser.commandsFor(newKind, keyword, base),
      );
}

/// The current room as the Room Insight panel shows it.
class RoomInsight {
  final String name;

  /// Full direction names, in the order the header listed them.
  final List<String> exits;

  final List<RoomEntity> entities;

  const RoomInsight({
    required this.name,
    required this.exits,
    this.entities = const [],
  });

  /// This room with the player's recategorisations applied, keyed by
  /// [RoomEntity.phrase].
  RoomInsight withOverrides(Map<String, RoomEntityKind> overrides) {
    if (overrides.isEmpty) return this;
    return RoomInsight(
      name: name,
      exits: exits,
      entities: [
        for (final e in entities)
          overrides[e.phrase] == null ? e : e.withKind(overrides[e.phrase]!),
      ],
    );
  }
}

/// Turns a room block (`Nice forest (n,e,s,w)` plus the lines listing what
/// is there) into a [RoomInsight].
///
/// Looser than [RoomLineClassifier.npcKeywordIn] on purpose: the panel lists
/// what the room *contains*, objects included, and a listing like
/// `An army of five ants.` is a creature here even though the kill-link
/// processor refuses its shape. Prose (`The path leads east.`) and player
/// lines (no leading article) are still left out.
///
/// The noun lists only cover things found all over the world. Something
/// unique to one room (`A wasps' nest.`) is left to the player to
/// recategorise in the panel rather than coded in here.
class RoomInsightParser {
  static const Map<String, String> _directions = {
    'n': 'north', 's': 'south', 'e': 'east', 'w': 'west',
    'ne': 'northeast', 'nw': 'northwest', 'se': 'southeast',
    'sw': 'southwest', 'u': 'up', 'd': 'down',
  };

  /// Object nouns missing from [RoomLineClassifier.nonTargetNouns] that a
  /// room still lists as loot.
  static const Set<String> objectNouns = {
    'crystal', 'crystals', 'feather', 'feathers', 'shell', 'shells',
    'acorn', 'acorns', 'pinecone', 'pinecones', 'twig', 'twigs', 'stick',
    'sticks', 'candy', 'sweet', 'sweets', 'nut', 'nuts', 'seed', 'seeds',
  };

  /// Objects fixed in place: Misc, offered `look at` (and `open`, `read` or
  /// `pull` where that is what you do with one) rather than `get`.
  static const Set<String> fixtureNouns = {
    'door', 'doors', 'gate', 'gates', 'portal', 'portals', 'archway', 'arch',
    'hatch', 'trapdoor', 'window', 'windows', 'sign', 'signs', 'signpost',
    'signposts', 'post', 'pole', 'board', 'boards', 'notice', 'plaque',
    'poster', 'placard', 'banner', 'altar', 'statue', 'fountain', 'well',
    'pool', 'pillar', 'column', 'throne', 'anvil', 'forge', 'furnace',
    'ladder', 'stairs', 'staircase', 'steps', 'bridge', 'lever', 'tree',
    'trees', 'boulder', 'grave', 'tombstone', 'gravestone', 'table', 'tables',
    'bench', 'bed', 'desk', 'shelf', 'shelves', 'cabinet', 'tapestry',
    'painting', 'mirror', 'cauldron', 'brazier', 'wagon', 'cart', 'boat',
  };

  static const Set<String> _openable = {
    'door', 'doors', 'gate', 'gates', 'hatch', 'trapdoor', 'window', 'cabinet',
  };

  static const Set<String> _readable = {
    'sign', 'signs', 'signpost', 'signposts', 'board', 'notice', 'plaque',
    'poster', 'placard', 'tombstone', 'gravestone',
  };

  /// Things you can `eat`.
  static const Set<String> edibleNouns = {
    'meat', 'steak', 'flesh', 'fish', 'bread', 'loaf', 'cheese', 'apple',
    'apples', 'pie', 'cake', 'egg', 'eggs', 'stew', 'soup', 'ration',
    'rations', 'food', 'fruit', 'berry', 'berries', 'mushroom', 'mushrooms',
    'honey', 'candy', 'sweet', 'sweets', 'nut', 'nuts', 'acorn', 'acorns',
    'crystal', 'crystals',
  };

  /// A word in front of the noun that makes any object edible
  /// (`A sugar crystal.`).
  static const Set<String> edibleModifiers = {
    'sugar', 'candy', 'honey', 'chocolate', 'sweet', 'roasted', 'cooked',
    'dried', 'fresh',
  };

  /// Things you `drink` rather than eat. Edible too.
  static const Set<String> drinkNouns = {
    'ale', 'beer', 'wine', 'mead', 'grog', 'rum', 'brandy', 'whisky',
    'whiskey', 'milk', 'potion', 'elixir', 'water', 'juice', 'tea',
  };

  static final RegExp _countedPattern = RegExp(r'^(\d+)\s+(.+?)\.?\s*$');
  static final RegExp _articlePattern =
      RegExp(r'^(A|An|The|Some)\s+(.+?)\.?\s*$');

  /// The commands the panel offers for something of [kind].
  static List<String> commandsFor(
      RoomEntityKind kind, String keyword, String base) {
    switch (kind) {
      case RoomEntityKind.npc:
        return ['look at $keyword', 'kill $keyword'];
      case RoomEntityKind.edible:
        return [
          'get $keyword',
          drinkNouns.contains(base) ? 'drink $keyword' : 'eat $keyword',
        ];
      case RoomEntityKind.item:
        return ['get $keyword', 'look at $keyword'];
      case RoomEntityKind.misc:
        return [
          'look at $keyword',
          if (_openable.contains(base)) 'open $keyword',
          if (_readable.contains(base)) 'read $keyword',
          if (base == 'lever') 'pull $keyword',
        ];
    }
  }

  /// The room name and exits from a header line, or `null` when [line]
  /// isn't one.
  static RoomInsight? parseHeader(String line) {
    final trimmed = line.trimRight();
    if (!RoomLineClassifier.isRoomHeader(trimmed)) return null;
    final open = trimmed.lastIndexOf('(');
    final name = trimmed.substring(0, open).trim();
    final exits = trimmed
        .substring(open + 1, trimmed.lastIndexOf(')'))
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => _directions[e] ?? e)
        .toList();
    return RoomInsight(name: name, exits: List.unmodifiable(exits));
  }

  /// The entity [line] lists, or `null` when it lists nothing. [seen] counts
  /// keywords already listed in this room so duplicates get their ordinal;
  /// it is updated.
  static RoomEntity? parseEntity(String line, Map<String, int> seen) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    final counted = _countedPattern.firstMatch(trimmed);
    if (counted != null) {
      final label = counted.group(2)!.trim();
      final words = _words(label);
      if (words.isEmpty || _isProse(trimmed, words)) return null;
      final base = words.last;
      final kind = _isEdible(base, words) ? RoomEntityKind.edible
          : RoomEntityKind.item;
      return _entity(kind, label, base, words.join(' '), trimmed, seen,
          count: int.tryParse(counted.group(1)!));
    }

    final m = _articlePattern.firstMatch(trimmed);
    if (m == null) return null;
    var phrase = m.group(2)!;
    final paren = phrase.indexOf('(');
    if (paren > 0) phrase = phrase.substring(0, paren).trim();
    // `An army of five ants` is an army: the head noun sits before `of`.
    final head = phrase.split(RegExp(r'\s+of\s+', caseSensitive: false)).first;
    final words = _words(head);
    if (words.isEmpty || _isProse(trimmed, words)) return null;

    final base = words.last;
    if (base.length > 3 && base.endsWith('ly')) return null;
    return _entity(
        _autoKind(base, words), null, base, _words(phrase).join(' '), trimmed,
        seen);
  }

  static RoomEntityKind _autoKind(String base, List<String> words) {
    if (fixtureNouns.contains(base)) return RoomEntityKind.misc;
    if (_isEdible(base, words)) return RoomEntityKind.edible;
    if (RoomLineClassifier.nonTargetNouns.contains(base) ||
        objectNouns.contains(base)) {
      return RoomEntityKind.item;
    }
    return RoomEntityKind.npc;
  }

  static bool _isEdible(String base, List<String> words) =>
      edibleNouns.contains(base) ||
      drinkNouns.contains(base) ||
      words.any((w) => edibleModifiers.contains(w));

  static RoomEntity _entity(RoomEntityKind kind, String? label, String base,
      String phrase, String line, Map<String, int> seen,
      {int? count}) {
    final keyword = _ordinal(base, seen);
    return RoomEntity(
      kind: kind,
      autoKind: kind,
      label: label ?? keyword,
      keyword: keyword,
      base: base,
      phrase: phrase,
      line: line,
      count: count,
      commands: commandsFor(kind, keyword, base),
    );
  }

  /// A sentence rather than a listing: a giveaway word anywhere, or a verb
  /// or function word inside the noun phrase.
  static bool _isProse(String line, List<String> phraseWords) {
    if (RoomLineClassifier.descriptionGiveaway.hasMatch(line)) return true;
    for (final w in phraseWords) {
      if (RoomLineClassifier.sentenceFunctionWords.contains(w)) return true;
      if (RoomLineClassifier.nonTargetVerbs.contains(w)) return true;
    }
    return false;
  }

  static String _ordinal(String base, Map<String, int> seen) {
    final n = (seen[base] ?? 0) + 1;
    seen[base] = n;
    return n == 1 ? base : '$base $n';
  }

  static List<String> _words(String phrase) => phrase
      .split(RegExp(r'\s+'))
      .map((w) => w
          .toLowerCase()
          .replaceAll(RegExp(r'^[^a-z0-9]+'), '')
          .replaceAll(RegExp(r'[^a-z0-9]+$'), ''))
      .where((w) => w.isNotEmpty)
      .toList();
}
