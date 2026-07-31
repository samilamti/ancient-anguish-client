import 'package:flutter/material.dart' show Color;

import '../../protocol/ansi/styled_span.dart';
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
/// Room headers and prompt lines are skipped outright: `West Gate (e,w)` is a
/// location, not a creature.
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

  /// Returns [line] with its kill targets promoted, or the original instance
  /// when nothing matched (cheap reference equality lets the buffer skip
  /// rebuilds).
  ///
  /// [npcKeyword] is the target the room parser extracted from this very line
  /// (see `RoomTargetsNotifier.processLine`), or null if it extracted none.
  StyledLine processLine(StyledLine line, {String? npcKeyword}) {
    final plain = line.plainText;
    if (plain.isEmpty) return line;
    if (RoomLineClassifier.isRoomHeader(plain) ||
        RoomLineClassifier.isPromptShape(plain)) {
      return line;
    }

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
