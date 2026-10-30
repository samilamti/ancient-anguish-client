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

/// Every creature instance in the current room, in the order the room listed
/// them, with Ancient Anguish's ordinal on the duplicates: two orcs give
/// `orc`, `orc 2` (AA accepts `kill orc 2`). This is what Tab cycles through.
///
/// [roomTargetsProvider] itself stays one entry per keyword, because the Kill
/// picker and the kill-link catalogue want each creature once.
final roomTargetInstancesProvider = Provider<List<String>>((ref) {
  final keywords = ref.watch(roomTargetsProvider);
  return expandTargetInstances(
      keywords, ref.read(roomTargetsProvider.notifier).counts);
});

/// Expands [keywords] into one entry per creature using [counts]: `orc` with
/// a count of 3 becomes `orc`, `orc 2`, `orc 3`. A missing count means one.
List<String> expandTargetInstances(
    List<String> keywords, Map<String, int> counts) {
  final out = <String>[];
  for (final k in keywords) {
    final n = counts[k] ?? 1;
    out.add(k);
    for (var i = 2; i <= n; i++) {
      out.add('$k $i');
    }
  }
  return List.unmodifiable(out);
}

class RoomTargetsNotifier extends Notifier<List<String>> {
  bool _inRoomBlock = false;
  final List<String> _pending = [];
  final Map<String, int> _pendingCounts = {};

  /// How many of each keyword the committed room block listed. Updated
  /// together with [state], so a listener of [roomTargetsProvider] always
  /// reads the counts that belong to the list it was handed.
  Map<String, int> counts = const {};

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
      // Only an unfinished block is committed here; a finished one already
      // was, and re-publishing it would hand listeners the room just left.
      if (_inRoomBlock) _commit();
      _inRoomBlock = true;
      _pending.clear();
      _pendingCounts.clear();
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
    _pendingCounts[target] = (_pendingCounts[target] ?? 0) + 1;
    return target;
  }

  /// Pushes the in-flight pending list into [state]. Called when the room
  /// block ends or a new one begins; the latest committed list is the one
  /// consumers see in `commonTargetsProvider`.
  void _commit() {
    if (_pending.isEmpty) {
      counts = const {};
      // A fresh list even when it was already empty: every room entered is
      // news to listeners (the target drops when you walk into an empty
      // room, as it does when you walk into a full one).
      state = List<String>.unmodifiable(const <String>[]);
      return;
    }
    counts = Map.unmodifiable(_pendingCounts);
    final next = List<String>.unmodifiable(_pending);
    state = next;
  }

  /// Test hook: clears state and the in-flight buffer. Production code
  /// shouldn't need this — the notifier resets organically on the next
  /// room header.
  void resetForTest() {
    _inRoomBlock = false;
    _pending.clear();
    _pendingCounts.clear();
    counts = const {};
    state = const [];
  }
}
