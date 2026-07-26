import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/parser/room_line_classifier.dart';

/// Targets detected by scanning the most-recently-rendered room block in
/// the terminal stream. Used as the primary seed for the Kill picker so
/// the player sees what's actually in front of them before falling back to
/// the static `kCommonTargets` list.
///
/// A "room block" starts on a line shaped like `Room Name (n,e,sw)` and
/// continues until the next room header, prompt line, or blank line. The
/// per-line shape tests live in [RoomLineClassifier] so the kill-target link
/// renderer agrees with this detector about what counts as a creature.
final roomTargetsProvider =
    NotifierProvider<RoomTargetsNotifier, List<String>>(
        RoomTargetsNotifier.new);

class RoomTargetsNotifier extends Notifier<List<String>> {
  bool _inRoomBlock = false;
  final List<String> _pending = [];

  @override
  List<String> build() => const [];

  /// Feeds one plain-text MUD output line through the parser. Drives the
  /// state machine that captures NPC targets between a room header and the
  /// next prompt / new room.
  ///
  /// Returns the target this line announced, or `null` if it announced none.
  /// The terminal buffer uses that return value to render the keyword as a
  /// tappable `kill` link on the very line that introduced it — which is why
  /// the answer has to come back per-line rather than only via [state], which
  /// isn't published until the block ends.
  String? processLine(String plainText) {
    final line = plainText.trimRight();

    if (RoomLineClassifier.isRoomHeader(line)) {
      _commit();
      _inRoomBlock = true;
      _pending.clear();
      return null;
    }

    if (!_inRoomBlock) return null;

    if (line.trim().isEmpty || RoomLineClassifier.isPromptShape(line)) {
      _commit();
      _inRoomBlock = false;
      return null;
    }

    final target = RoomLineClassifier.npcKeywordIn(line);
    if (target == null) return null;
    if (!_pending.contains(target)) _pending.add(target);
    return target;
  }

  /// Pushes the in-flight pending list into [state]. Called when the room
  /// block ends or a new one begins; the latest committed list is the one
  /// consumers see in `commonTargetsProvider`.
  void _commit() {
    if (_pending.isEmpty) {
      if (state.isNotEmpty) state = const [];
      return;
    }
    final next = List<String>.unmodifiable(_pending);
    state = next;
  }

  /// Test hook: clears state and the in-flight buffer. Production code
  /// shouldn't need this — the notifier resets organically on the next
  /// room header.
  void resetForTest() {
    _inRoomBlock = false;
    _pending.clear();
    state = const [];
  }
}
