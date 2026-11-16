import '../parser/battle_text_classifier.dart';

/// Steps through a Kata: up to ten combat actions, one per second, looping
/// for as long as the fight lasts.
///
/// Pure and clock-free: the caller asks for the next action once a second and
/// decides when a fight starts and ends. Empty slots are real seconds of
/// doing nothing, except the empty slots after the last action, which are
/// dropped so a three-action Kata loops every three seconds rather than ten.
class KataEngine {
  KataEngine(List<String> slots) : _slots = _trim(slots);

  final List<String> _slots;
  int _step = 0;

  /// Seconds in one pass through the Kata; 0 when every slot is empty.
  int get length => _slots.length;

  bool get isEmpty => _slots.isEmpty;

  /// The 1-based slot the next call to [next] will fire.
  int get nextSlot => _step + 1;

  /// The action for this second (`null` for an empty slot), then moves on,
  /// wrapping to slot 1 after the last action.
  String? next() {
    if (_slots.isEmpty) return null;
    final command = _slots[_step];
    _step = (_step + 1) % _slots.length;
    return command.isEmpty ? null : command;
  }

  /// Back to slot 1, for the next fight.
  void reset() => _step = 0;

  static List<String> _trim(List<String> slots) {
    final cleaned = [for (final s in slots) s.trim()];
    var end = cleaned.length;
    while (end > 0 && cleaned[end - 1].isEmpty) {
      end--;
    }
    return List.unmodifiable(cleaned.sublist(0, end));
  }

  /// Whether [kind] means the player is in an exchange of blows. Only blows
  /// you deal or take start a Kata: watching a pet or another player fight,
  /// or an `HP:`/`SP:` line on its own, does not.
  static bool startsFight(BattleLineKind kind) => switch (kind) {
        BattleLineKind.yourHit ||
        BattleLineKind.yourMiss ||
        BattleLineKind.incomingHit ||
        BattleLineKind.incomingMiss =>
          true,
        _ => false,
      };
}
