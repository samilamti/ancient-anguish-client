/// Remembers when a movement command last went to the MUD, so command
/// triggers can stay quiet while the player is walking through rooms (and
/// not, say, attack an NPC they are only running past).
///
/// Fed from the connection services' `sendCommand`, the one place every
/// outgoing line passes through: typed input, the D-pad, alias expansions,
/// links and triggers alike.
class MovementTracker {
  MovementTracker({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// The app-wide tracker.
  static final instance = MovementTracker();

  /// How long after the last movement command the player still counts as
  /// moving. Covers the arrival output of the room just entered.
  static const movingWindow = Duration(seconds: 2);

  static final _movement = RegExp(
    r'^(?:n|s|e|w|ne|nw|se|sw|u|d|north|south|east|west|northeast|northwest|'
    r'southeast|southwest|up|down|out|in|leave|enter(?:\s.*)?|go\s.+)$',
    caseSensitive: false,
  );

  /// Whether [command] moves the player to another room.
  static bool isMovement(String command) =>
      _movement.hasMatch(command.trim());

  final DateTime Function() _clock;
  DateTime? _lastMove;

  DateTime? get lastMove => _lastMove;

  void noteCommand(String command) {
    if (isMovement(command)) _lastMove = _clock();
  }

  /// Whether a movement command was sent within [movingWindow] of [now].
  bool isMoving([DateTime? now]) {
    final last = _lastMove;
    if (last == null) return false;
    return (now ?? _clock()).difference(last) < movingWindow;
  }
}
