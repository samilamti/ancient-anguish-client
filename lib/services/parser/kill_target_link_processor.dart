import 'package:flutter/material.dart' show Color;

import '../../protocol/ansi/styled_span.dart';
import 'battle_text_classifier.dart';
import 'room_line_classifier.dart';
import 'text_link_processor.dart';

/// Promotes attackable creatures in MUD output to tappable `kill <target>`
/// links, tinted [linkColor].
///
/// Two modes, in priority order — the split exists because a flat "any known
/// target word, anywhere" scan produces embarrassing links:
///
/// 1. **Announcement line.** When the room parser has just accepted this line
///    as an NPC announcement, [processLine] is given its keyword and links
///    *only* that word. `A giant eagle.` links `eagle`, not the `giant` that
///    happens to sit in the static catalogue. Lines whose head noun is
///    scenery (`A shimmering blue door.`) never produce a keyword, so they
///    fall through to mode 2 rather than linking `door`.
/// 2. **Catalogue scan.** Otherwise every known target word on the line is
///    linked, so combat and prose mentions ("The goblin hits you.") stay
///    tappable. Adjacent catalogue words collapse to the later one —
///    "giant orc" links `orc`, since the first of a bare noun pair is almost
///    always doing adjective duty.
///
/// Whole *lines* are skipped before either mode runs — see [skipsLine]. A
/// creature's name appearing in a line is not the same as the creature being
/// offered to you, and the difference is what stops the screen turning red the
/// moment a fight starts.
///
/// [ignored] words are dropped from *both* modes — it is the user's runtime
/// blocklist, so an announcement keyword the room parser accepted is silenced
/// just as surely as a catalogue word.
class KillTargetLinkProcessor {
  /// Recolours promoted spans so kill links read differently from the user's
  /// own text-link rules, which keep their surrounding ANSI colour.
  final Color? linkColor;

  /// One word-bounded alternation over every known target, so a line is
  /// scanned once regardless of catalogue size. Null when there are none.
  final RegExp? _catalogue;

  /// Normalized words the user has muted, checked on the announcement path.
  final Set<String> _ignored;

  /// Both the catalogue filter and the announcement check need the normalized
  /// ignore set, and an initializer list can't share a local — hence the
  /// factory plus private constructor.
  factory KillTargetLinkProcessor(
    Iterable<String> targets, {
    Color? linkColor,
    Iterable<String> ignored = const [],
  }) {
    final muted = _normalizeAll(ignored);
    return KillTargetLinkProcessor._(
      linkColor: linkColor,
      ignored: muted,
      catalogue: _buildCatalogue(targets, muted),
    );
  }

  const KillTargetLinkProcessor._({
    required this.linkColor,
    required Set<String> ignored,
    required RegExp? catalogue,
  })  : _ignored = ignored,
        _catalogue = catalogue;

  static Set<String> _normalizeAll(Iterable<String> words) => words
      .map((w) => w.trim().toLowerCase())
      .where((w) => w.isNotEmpty)
      .toSet();

  static RegExp? _buildCatalogue(
    Iterable<String> targets,
    Set<String> ignored,
  ) {
    // Longest-first so a target isn't cut short by a shorter one sharing its
    // prefix; escaped because room-derived targets are arbitrary MUD text.
    final words = targets
        .where((t) => t.isNotEmpty)
        .where((t) => !ignored.contains(t.trim().toLowerCase()))
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (words.isEmpty) return null;
    final alternation = words.map(RegExp.escape).join('|');
    return RegExp('\\b($alternation)\\b', caseSensitive: false);
  }

  bool get isEmpty => _catalogue == null;

  /// Speech: `An orc seems to exclaim: An trp!  Par, skxxa!`
  ///
  /// Anchored on a speech verb followed by its colon, because the colon alone
  /// appears in far too much ordinary output to key off. What the creature is
  /// *saying* is quoted text, and a target word inside it — or inside the
  /// creature's own name in the attribution — is not an offer to attack
  /// anything; the room listing that introduced it already was.
  static final RegExp _speechPattern = RegExp(
    r'\b(?:says?|said|exclaims?|exclaim|asks?|ask|shouts?|shout|yells?|yell|'
    r'whispers?|whisper|tells?|tell|replies|reply|answers?|answer|mutters?|'
    r'mutter|growls?|growl|snarls?|snarl|screams?|scream|chants?|chant|'
    r'sings?|sing|cries|cry|utters?|utter|declares?|declare|announces?|'
    r'announce|remarks?|remark)\b[^:]{0,24}:',
    caseSensitive: false,
  );

  /// A creature in an ongoing state: `Orc is panicking and trying to flee.`
  ///
  /// Two tells together, and both are load-bearing. The progressive says the
  /// line reports something happening rather than something present; the
  /// **absent article** says the MUD is naming a creature already in play,
  /// which is how AA writes combat participants (`Orc died.`, `Orc is
  /// panicking…`). Requiring both is what keeps an article-led room listing —
  /// `A large goblin is standing here.` — out of this, since that one is a
  /// creature being offered and should keep its link.
  ///
  /// The leading negative lookahead is what enforces the second tell: without
  /// it `A` is simply eaten as the first capitalised word of the name, and
  /// `A large orc is standing here.` matches after all.
  static final RegExp _creatureStatePattern = RegExp(
    r"^(?!(?:A|An|The|Some)\s)"
    r"[A-Z][\w'’-]*(?:\s+[\w'’-]+){0,3}\s+"
    r"(?:is|are|was|were)\s+(?:\w+\s+)?\w+ing\b",
  );

  /// Combat kinds that rule a line out on their own.
  ///
  /// Deliberately *not* every kind the classifier recognises. Its miss and
  /// defense patterns are the loose ones and reach ordinary prose —
  /// `Troll blocks your way.` classifies as a dodge — which is exactly a line
  /// the player wants a `kill troll` link on. The hit and resolution patterns
  /// are anchored (a body part; a death verb), so a match there really is a
  /// fight in progress. The rest of combat is covered far more reliably by the
  /// caller's battle-mode gate, which drops every link for the duration.
  static const Set<BattleLineKind> _blockingKinds = {
    BattleLineKind.yourHit,
    BattleLineKind.incomingHit,
    BattleLineKind.otherHit,
    BattleLineKind.resolution,
  };

  /// What is left of something already dead: `The corpse of a bugbear.`
  ///
  /// Its name is still in there, and the catalogue scan will happily offer to
  /// attack it. Matched on the `<remains> of` idiom rather than the noun alone
  /// so a creature whose own name contains one (`A bone golem.`) is untouched.
  static final RegExp _deadThingPattern = RegExp(
    r'\b(?:corpse|corpses|remains|carcass|carcasses|skeleton|bones|head|'
    r'skull|hide|pelt|meat|flesh)\s+of\b',
    caseSensitive: false,
  );

  /// Whether [plain] is a line no kill link belongs on, whatever it names.
  ///
  /// Six shapes, each of which mentions a creature without presenting one:
  ///
  ///  * a room header or prompt — `West Gate (e,w)` is a location;
  ///  * speech — what an NPC *says* is quoted text;
  ///  * a blow or a death — `Orc died.` least of all wants a `kill orc` link;
  ///  * a creature-state report — `Orc is panicking and trying to flee.`;
  ///  * a dead thing — `The corpse of Orc`;
  ///  * **an item listing** — a line whose whole subject is something you
  ///    cannot attack. The room classifier already refuses to take a keyword
  ///    from one, and letting it fall through to the catalogue scan quietly
  ///    overrules that with a *worse* answer: `Some goat meat` is refused as
  ///    `kill meat`, then linked as `kill goat`. See
  ///    [RoomLineClassifier.announcesNonTarget].
  static bool skipsLine(String plain) {
    final trimmed = plain.trim();
    if (RoomLineClassifier.isRoomHeader(plain) ||
        RoomLineClassifier.isPromptShape(plain)) {
      return true;
    }
    if (_speechPattern.hasMatch(plain)) return true;
    if (_blockingKinds.contains(BattleTextClassifier.classify(plain)?.kind)) {
      return true;
    }
    if (_creatureStatePattern.hasMatch(trimmed)) return true;
    if (_deadThingPattern.hasMatch(plain)) return true;
    if (RoomLineClassifier.announcesNonTarget(plain)) return true;
    return false;
  }

  /// Returns [line] with its kill targets promoted, or the original instance
  /// when nothing matched (cheap reference equality lets the buffer skip
  /// rebuilds).
  ///
  /// [npcKeyword] is the target the room parser extracted from this very line
  /// (see `RoomTargetsNotifier.processLine`), or null if it extracted none.
  StyledLine processLine(StyledLine line, {String? npcKeyword}) {
    final plain = line.plainText;
    if (plain.isEmpty) return line;
    if (skipsLine(plain)) return line;

    final hits = npcKeyword != null
        ? (_ignored.contains(npcKeyword.trim().toLowerCase())
            ? const <CommandHit>[]
            : _announcementHit(plain, npcKeyword))
        : _catalogueHits(plain);
    if (hits.isEmpty) return line;
    return promoteCommandSpans(line, hits, linkColor: linkColor);
  }

  /// The last whole-word occurrence of [keyword] — the head noun sits at the
  /// end of an announcement, and a name can repeat ("The bear cub bear.").
  List<CommandHit> _announcementHit(String plain, String keyword) {
    final re = RegExp('\\b${RegExp.escape(keyword)}\\b', caseSensitive: false);
    Match? last;
    for (final m in re.allMatches(plain)) {
      last = m;
    }
    if (last == null) return const [];
    return [CommandHit(last.start, last.end, 'kill $keyword')];
  }

  List<CommandHit> _catalogueHits(String plain) {
    final re = _catalogue;
    if (re == null) return const [];

    final matches = re.allMatches(plain).toList();
    if (matches.isEmpty) return const [];

    final hits = <CommandHit>[];
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      // Drop a match that is immediately followed by another match with only
      // whitespace between — "giant orc" is an adjective plus its noun, and
      // the noun is what you attack.
      if (i + 1 < matches.length) {
        final gap = plain.substring(m.end, matches[i + 1].start);
        if (gap.isNotEmpty && gap.trim().isEmpty) continue;
      }
      hits.add(CommandHit(
        m.start,
        m.end,
        'kill ${m.group(0)!.toLowerCase()}',
      ));
    }
    return hits;
  }
}
