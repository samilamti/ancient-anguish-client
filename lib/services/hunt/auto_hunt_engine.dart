import 'dart:math';

import '../parser/room_line_classifier.dart';

/// One room as the MUD printed it: the exits from its header and the lines
/// of its block (description, items, creatures).
class RoomSighting {
  const RoomSighting({required this.exits, required this.lines});

  final List<String> exits;
  final List<String> lines;

  /// Parses the exit list out of a `Room Name (n,e,sw)` header, or returns
  /// null when [header] isn't one.
  static List<String>? exitsOf(String header) {
    final m = RoomLineClassifier.roomHeaderPattern.firstMatch(header.trimRight());
    if (m == null) return null;
    return [
      for (final e in m.group(1)!.split(','))
        if (e.trim().isNotEmpty) e.trim().toLowerCase(),
    ];
  }
}

/// Turns MUD output, one line at a time, into [RoomSighting]s.
///
/// Two room shapes reach the hunter. Walking prints a header with short
/// exits, `Forest path (n,e,w)`, and the block runs to the next blank or
/// prompt line. `look` instead prints the description, then the exits spelled
/// out on their own lines:
///
/// ```text
///  Obvious directions are:
///   north, east, west.
/// A little spider.
/// ```
///
/// The exit list runs until a line ends in a period, and the creatures
/// follow it. Spelled-out directions are folded to the short form
/// (`north` → `n`), so both shapes look the same to the engine.
class RoomBlockReader {
  static final _obvious = RegExp(
    r'obvious\s+(?:exits?|directions?)\b[^:]*:?\s*(.*)$',
    caseSensitive: false,
  );

  static const _short = {
    'north': 'n', 'south': 's', 'east': 'e', 'west': 'w',
    'northeast': 'ne', 'northwest': 'nw', 'southeast': 'se',
    'southwest': 'sw', 'up': 'u', 'down': 'd',
  };

  /// Upper bound on a block's lines, so chatter after a room with no blank
  /// line or prompt still lets the sighting go out.
  static const maxLines = 40;

  List<String>? _exits;
  final List<String> _lines = [];

  /// True while the spelled-out exit list is still being read.
  bool _readingExits = false;

  /// Folds `north`/`North`/`n` to `n`; anything else is kept lowercased.
  static String shortDirection(String word) {
    final w = word.trim().toLowerCase();
    return _short[w] ?? w;
  }

  /// Splits `north, east and west.` into `[n, e, w]`.
  static List<String> parseDirectionList(String text) => [
        for (final part in text
            .replaceAll(RegExp(r'[.:]'), ' ')
            .split(RegExp(r',|\s+and\s+|\s+')))
          if (part.trim().isNotEmpty) shortDirection(part),
      ];

  /// Feeds one plain-text line; returns a room when one has just finished.
  RoomSighting? feed(String plainText) {
    final line = plainText.trimRight();
    final trimmed = line.trim();

    final headerExits = RoomSighting.exitsOf(line);
    if (headerExits != null) {
      final done = _finish();
      _exits = [for (final e in headerExits) shortDirection(e)];
      return done;
    }

    final obvious = _obvious.firstMatch(trimmed);
    if (obvious != null) {
      // A look block has no header; the exit line is what opens it. Lines
      // already collected under a header belong to the same room.
      _exits = parseDirectionList(obvious.group(1)!);
      _readingExits = !trimmed.endsWith('.');
      return null;
    }

    if (_exits == null) return null;

    if (_readingExits) {
      _exits!.addAll(parseDirectionList(trimmed));
      if (trimmed.endsWith('.') || trimmed.isEmpty) _readingExits = false;
      return null;
    }

    if (trimmed.isEmpty || RoomLineClassifier.isPromptShape(line)) {
      return _finish();
    }
    _lines.add(line);
    return _lines.length >= maxLines ? _finish() : null;
  }

  /// Ends the current block, if any, and returns it.
  RoomSighting? _finish() {
    final exits = _exits;
    _exits = null;
    _readingExits = false;
    if (exits == null) {
      _lines.clear();
      return null;
    }
    final room = RoomSighting(exits: exits, lines: List.of(_lines));
    _lines.clear();
    return room;
  }
}

/// The decisions behind Auto Hunt: walk the world one room at a time through
/// n/s/e/w exits, `kill` anything on the target list, and leave any room that
/// holds something on the avoid list.
///
/// Pure and clock-driven, so the whole policy is testable without a timer or
/// a socket. The owner feeds it rooms ([onRoom]) and polls it ([tick]); each
/// tick returns at most one command to send.
class AutoHuntEngine {
  AutoHuntEngine({
    required List<String> targets,
    required List<String> avoid,
    required this.stepDelay,
    Random? random,
  }) : _random = random ?? Random() {
    configure(targets: targets, avoid: avoid, stepDelay: stepDelay);
  }

  /// Replaces the lists and pace without forgetting where the hunter is.
  void configure({
    required List<String> targets,
    required List<String> avoid,
    required Duration stepDelay,
  }) {
    this.stepDelay = stepDelay;
    _targetTexts = [for (final t in targets) t.trim().toLowerCase()];
    _targets = [for (final t in targets) _phrase(t)];
    _avoid = [for (final a in avoid) _phrase(a)];
  }

  /// The only directions Auto Hunt will walk.
  static const allowedDirections = ['n', 's', 'e', 'w'];

  /// Pause after arriving before attacking, so the room output settles.
  static const killDelay = Duration(seconds: 1);

  /// How long a `kill` gets to start a fight before the target counts as
  /// unreachable in this room.
  static const killTimeout = Duration(seconds: 5);

  /// How long a move or `look` gets to print a room before it counts as
  /// failed (closed door, "You can't go that way").
  static const roomTimeout = Duration(seconds: 8);

  /// Pause between the end of a fight and the `look` that re-reads the room.
  static const afterCombatDelay = Duration(seconds: 2);

  /// Pause between rooms when nothing is worth attacking.
  Duration stepDelay;

  List<String> _targetTexts = const [];
  List<RegExp> _targets = const [];
  List<RegExp> _avoid = const [];
  final Random _random;

  RoomSighting? _room;
  DateTime? _arrivedAt;
  DateTime? _lastActionAt;

  /// Last direction walked, so the hunter doesn't just pace back and forth.
  String? _lastMove;

  /// A move or look is out and no room has come back yet.
  DateTime? _awaitingRoomSince;
  String? _awaitingMove;

  /// Directions that failed from the current room.
  final Set<String> _failedDirs = {};

  /// Keywords already tried with `kill` in this sighting of the room.
  final Set<String> _triedKills = {};
  String? _pendingKill;
  DateTime? _pendingKillAt;

  bool _avoidHere = false;
  bool _wasInCombat = false;
  DateTime? _combatEndedAt;

  /// Human-readable account of the last decision, for the settings screen.
  String status = 'Waiting for a room';

  /// True when the current room has no usable exit; the owner should stop.
  bool stuck = false;

  static RegExp _phrase(String text) => RegExp(
        r'\b' + RegExp.escape(text.trim()) + r'\b',
        caseSensitive: false,
      );

  /// A room block has finished printing.
  void onRoom(RoomSighting room, DateTime now) {
    final moved = _awaitingMove;
    _room = room;
    _arrivedAt = now;
    _awaitingRoomSince = null;
    _awaitingMove = null;
    if (moved != null) _lastMove = moved;
    _failedDirs.clear();
    _triedKills.clear();
    _pendingKill = null;
    _pendingKillAt = null;
    stuck = false;
    final threat = _firstPresent(room, _avoid);
    _avoidHere = threat != null;
    if (threat != null) status = 'Avoiding "$threat"';
  }

  /// Returns the next command to send, or null to wait.
  String? tick({required DateTime now, required bool inCombat}) {
    if (stuck) return null;

    final room = _room;
    if (room == null) {
      final since = _awaitingRoomSince;
      if (since != null && now.difference(since) < roomTimeout) return null;
      return _look(now, 'Looking around');
    }

    // Leaving comes before everything, a fight included.
    if (_avoidHere) {
      if (_awaitingRoomSince != null &&
          now.difference(_awaitingRoomSince!) < roomTimeout) {
        return null;
      }
      if (_awaitingMove != null) _failedDirs.add(_awaitingMove!);
      final dir = _escapeDirection(room);
      if (dir == null) return _stuck();
      return _move(dir, now, 'Avoiding: heading $dir');
    }

    if (inCombat) {
      _wasInCombat = true;
      _pendingKill = null;
      status = 'Fighting';
      return null;
    }
    if (_wasInCombat) {
      _wasInCombat = false;
      _combatEndedAt = now;
    }
    final ended = _combatEndedAt;
    if (ended != null) {
      if (now.difference(ended) < afterCombatDelay) return null;
      _combatEndedAt = null;
      // The fight changed the room (a corpse, maybe a second spider), so
      // read it again rather than trusting the old sighting.
      _room = null;
      return _look(now, 'Fight over, looking around');
    }

    final since = _awaitingRoomSince;
    if (since != null) {
      if (now.difference(since) < roomTimeout) return null;
      // No room came back: the way is blocked. Try another one.
      _awaitingRoomSince = null;
      if (_awaitingMove != null) _failedDirs.add(_awaitingMove!);
      _awaitingMove = null;
    }

    final pending = _pendingKill;
    if (pending != null) {
      if (now.difference(_pendingKillAt!) < killTimeout) return null;
      _triedKills.add(pending);
      _pendingKill = null;
    }

    if (now.difference(_arrivedAt!) >= killDelay) {
      final keyword = _targetKeyword(room);
      if (keyword != null) {
        _pendingKill = keyword;
        _pendingKillAt = now;
        _lastActionAt = now;
        status = 'Attacking $keyword';
        return 'kill $keyword';
      }
    }

    final last = _lastActionAt ?? _arrivedAt!;
    if (now.difference(last) < stepDelay ||
        now.difference(_arrivedAt!) < stepDelay) {
      status = 'Nothing here, moving on shortly';
      return null;
    }
    final dir = _wanderDirection(room);
    if (dir == null) return _stuck();
    return _move(dir, now, 'Heading $dir');
  }

  String _look(DateTime now, String why) {
    _awaitingRoomSince = now;
    _awaitingMove = null;
    _lastActionAt = now;
    status = why;
    return 'look';
  }

  String _move(String dir, DateTime now, String why) {
    _awaitingRoomSince = now;
    _awaitingMove = dir;
    _lastActionAt = now;
    status = why;
    return dir;
  }

  String? _stuck() {
    stuck = true;
    status = 'No n/s/e/w exit to take';
    return null;
  }

  List<String> _usable(RoomSighting room) => [
        for (final d in allowedDirections)
          if (room.exits.contains(d) && !_failedDirs.contains(d)) d,
      ];

  /// Back the way it came if possible: that room was safe a moment ago.
  String? _escapeDirection(RoomSighting room) {
    final usable = _usable(room);
    if (usable.isEmpty) return null;
    final back = _reverse(_lastMove);
    if (back != null && usable.contains(back)) return back;
    return usable[_random.nextInt(usable.length)];
  }

  /// Anywhere but back, unless back is the only way out.
  String? _wanderDirection(RoomSighting room) {
    final usable = _usable(room);
    if (usable.isEmpty) return null;
    final back = _reverse(_lastMove);
    final forward = [for (final d in usable) if (d != back) d];
    final pool = forward.isEmpty ? usable : forward;
    return pool[_random.nextInt(pool.length)];
  }

  static String? _reverse(String? dir) => switch (dir) {
        'n' => 's',
        's' => 'n',
        'e' => 'w',
        'w' => 'e',
        _ => null,
      };

  /// The `kill` keyword for the first target present, skipping ones that
  /// already failed to start a fight here.
  String? _targetKeyword(RoomSighting room) {
    for (final line in room.lines) {
      if (!_isPresenceLine(line)) continue;
      for (var i = 0; i < _targets.length; i++) {
        if (!_targets[i].hasMatch(line)) continue;
        final keyword = RoomLineClassifier.npcKeywordIn(line.trim()) ??
            _targetTexts[i].split(' ').last;
        if (_triedKills.contains(keyword)) continue;
        return keyword;
      }
    }
    return null;
  }

  /// The text of the first avoid entry present, or null.
  static String? _firstPresent(RoomSighting room, List<RegExp> phrases) {
    for (final line in room.lines) {
      if (!_isPresenceLine(line)) continue;
      for (final p in phrases) {
        final m = p.firstMatch(line);
        if (m != null) return m.group(0);
      }
    }
    return null;
  }

  /// A line announcing something in the room, as opposed to description
  /// prose that might merely mention a spider.
  static bool _isPresenceLine(String line) {
    final t = line.trim();
    return RoomLineClassifier.npcKeywordIn(t) != null ||
        RoomLineClassifier.npcLinePattern.hasMatch(t);
  }
}
