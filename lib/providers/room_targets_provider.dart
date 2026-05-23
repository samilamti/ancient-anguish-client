import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Targets detected by scanning the most-recently-rendered room block in
/// the terminal stream. Used as the primary seed for the Kill picker so
/// the player sees what's actually in front of them before falling back to
/// the static `kCommonTargets` list.
///
/// A "room block" starts on a line shaped like `Room Name (n,e,sw)` and
/// continues until the next room header, prompt line, or blank line. NPC
/// lines inside that block match `A|An|The|Some <words>.` — the last word
/// before the period is taken as the target keyword (lowercased).
final roomTargetsProvider =
    NotifierProvider<RoomTargetsNotifier, List<String>>(
        RoomTargetsNotifier.new);

class RoomTargetsNotifier extends Notifier<List<String>> {
  static final RegExp _roomHeaderPattern = RegExp(
    r'^[A-Z][^()\n]*\(([nsewud]{1,2}(,\s*[nsewud]{1,2})*)\)\s*$',
  );

  static final RegExp _npcLinePattern = RegExp(
    r'^(A|An|The|Some)\s+\S+(\s+\S+){0,3}\.\s*$',
  );

  /// Words that almost always indicate a description line ("The grass is
  /// damp.", "The path leads east.") rather than a discrete NPC. If any
  /// of these appear as a whole word in the line, the line is skipped.
  static final RegExp _descriptionGiveaway = RegExp(
    r'\b(is|are|was|were|has|have|had|leads|goes|stands|sits|lies|hangs|smells|seems|appears|here|there)\b',
    caseSensitive: false,
  );

  static final RegExp _promptShape = RegExp(r'^[<\[].*[>\]]\s*$');

  bool _inRoomBlock = false;
  final List<String> _pending = [];

  @override
  List<String> build() => const [];

  /// Feeds one plain-text MUD output line through the parser. Drives the
  /// state machine that captures NPC targets between a room header and the
  /// next prompt / new room.
  void processLine(String plainText) {
    final line = plainText.trimRight();

    if (_roomHeaderPattern.hasMatch(line)) {
      _commit();
      _inRoomBlock = true;
      _pending.clear();
      return;
    }

    if (!_inRoomBlock) return;

    if (line.trim().isEmpty || _promptShape.hasMatch(line)) {
      _commit();
      _inRoomBlock = false;
      return;
    }

    if (_npcLinePattern.hasMatch(line) &&
        !_descriptionGiveaway.hasMatch(line)) {
      final target = _extractTarget(line);
      if (target != null && !_pending.contains(target)) _pending.add(target);
    }
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

  /// Returns the last whitespace-separated word with trailing `.` removed
  /// and any parenthesised status marker (e.g. ` (fighting)`) stripped.
  /// Lowercased so it can be appended to `kill ` directly.
  static String? _extractTarget(String line) {
    var s = line.trim();
    final paren = s.indexOf('(');
    if (paren > 0) s = s.substring(0, paren).trimRight();
    if (s.endsWith('.')) s = s.substring(0, s.length - 1).trimRight();
    if (s.isEmpty) return null;
    final words = s.split(RegExp(r'\s+'));
    if (words.length < 2) return null;
    return words.last.toLowerCase();
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
