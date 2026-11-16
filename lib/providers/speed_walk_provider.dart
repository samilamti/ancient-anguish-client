import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/speedwalk/speed_walk.dart';
import 'notification_provider.dart';

/// Speed walking (local only, same marker asset as command triggers): typing
/// `21ne` sends the moves at once and hides the rooms on the way, so the
/// player appears in the target room. While a walk runs, output parsing is
/// off entirely: no triggers, text rules, links, maps or game state. It
/// resumes at the target room's header, after two refused moves, or after
/// [failsafe], whichever comes first.
final speedWalkProvider =
    NotifierProvider<SpeedWalkNotifier, bool>(SpeedWalkNotifier.new);

class SpeedWalkNotifier extends Notifier<bool> {
  /// Parsing always resumes this long after a walk starts, whatever the MUD
  /// did or didn't say.
  static const failsafe = Duration(seconds: 3);

  SpeedWalkTracker? _tracker;
  Timer? _timer;

  /// True while a walk runs.
  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  /// Starts following a walk of [path]. The caller sends the moves.
  void begin(SpeedWalkPath path) {
    _timer?.cancel();
    _tracker = SpeedWalkTracker(path.moves.length);
    _timer = Timer(failsafe, () => _end('no arrival after 3s'));
    state = true;
  }

  /// Decides one line of MUD output; true means gag it and parse nothing.
  /// [text] is the line with any leading prompt stripped. Cheap when no walk
  /// is running.
  bool swallow(String text) {
    final tracker = _tracker;
    if (tracker == null) return false;
    switch (tracker.feed(text)) {
      case SpeedWalkLine.swallow:
        return true;
      case SpeedWalkLine.arrived:
        _end(null);
        return false;
      case SpeedWalkLine.aborted:
        _end('moves refused after ${tracker.arrived} of ${tracker.total} '
            'rooms');
        return false;
    }
  }

  /// Ends any walk without a message (disconnect).
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _tracker = null;
    state = false;
  }

  void _end(String? problem) {
    cancel();
    if (problem != null) {
      ref
          .read(appNotificationsProvider.notifier)
          .show('Speed walk stopped: $problem');
    }
  }
}
