import '../parser/room_line_classifier.dart';

/// A local-only speed walk such as `21ne`: north 21 times, then east once.
///
/// Every letter is one direction (`n s e w u d`) and the number before it,
/// if any, is how many times to take it. So `ne` here is north then east,
/// never northeast. A path needs at least one number, which keeps a plain
/// `ne`, `sw` or `u` going to the MUD as the command it always was.
class SpeedWalkPath {
  const SpeedWalkPath(this.moves);

  /// One entry per room: `n`, `n`, …, `e`.
  final List<String> moves;

  /// Longest walk accepted; a typo like `9999n` is refused, not sent.
  static const maxMoves = 200;

  static final RegExp _whole = RegExp(r'^(?:\d*[nsewud])+$');
  static final RegExp _step = RegExp(r'(\d*)([nsewud])');

  /// Returns `null` when [input] is not a speed walk.
  static SpeedWalkPath? parse(String input) {
    final text = input.trim().toLowerCase();
    if (!_whole.hasMatch(text) || !text.contains(RegExp(r'\d'))) return null;
    final moves = <String>[];
    for (final m in _step.allMatches(text)) {
      final count = m.group(1)!.isEmpty ? 1 : int.parse(m.group(1)!);
      if (count < 1 || moves.length + count > maxMoves) return null;
      for (var i = 0; i < count; i++) {
        moves.add(m.group(2)!);
      }
    }
    return moves.length < 2 ? null : SpeedWalkPath(moves);
  }
}

/// What the walker decided about one line of MUD output.
enum SpeedWalkLine {
  /// Mid-walk: hide it, parse nothing.
  swallow,

  /// The target room's header: the walk is over and this line, like
  /// everything after it, is parsed normally.
  arrived,

  /// Too many refused moves: the walk is over and this line is shown.
  aborted,
}

/// Follows a walk through the MUD's output. Pure: the caller sends the
/// moves, owns the three-second failsafe, and gags whatever this says to.
///
/// Arrival is counted by room headers (`Forest path (n,e,w)`), which the MUD
/// prints once for every room walked into. The header of the last room ends
/// the walk, so the target room is shown and parsed in full while every room
/// on the way stays hidden.
class SpeedWalkTracker {
  SpeedWalkTracker(this.total);

  /// Rooms to walk.
  final int total;

  /// Refusals that abort the walk. One could be a stray line; two mean the
  /// path is wrong and the moves still queued will only be refused too.
  static const maxRefusals = 2;

  static final RegExp _refusal = RegExp(
    r"^(?:what\s*\?|there'?s no such exit|there is no such exit|"
    r"you can'?t go that way|you cannot go that way|"
    r"there is no exit|no exit in that direction|"
    r"you can'?t go there|alas, you cannot go that way)",
    caseSensitive: false,
  );

  int arrived = 0;
  int refusals = 0;

  /// Whether [text] reads as the MUD refusing a move.
  static bool isRefusal(String text) => _refusal.hasMatch(text.trim());

  /// Feeds one line of output, with any leading prompt already stripped.
  SpeedWalkLine feed(String text) {
    if (RoomLineClassifier.roomHeaderPattern.hasMatch(text.trimRight())) {
      arrived++;
      if (arrived >= total) return SpeedWalkLine.arrived;
    } else if (isRefusal(text)) {
      refusals++;
      if (refusals >= maxRefusals) return SpeedWalkLine.aborted;
    }
    return SpeedWalkLine.swallow;
  }
}
