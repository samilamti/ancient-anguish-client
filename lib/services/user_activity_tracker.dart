import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Remembers when the player last touched the client: a key press, a pointer
/// press or a scroll anywhere in the app. Command triggers read it so they only
/// act once the player has stepped away.
///
/// Mouse hover deliberately does not count — a resting hand nudges the cursor
/// constantly, and that would keep triggers off forever on desktop.
///
/// Soft-keyboard typing never reaches [HardwareKeyboard], so the input bar
/// calls [markInteraction] itself as text changes.
class UserActivityTracker {
  UserActivityTracker({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    // Launching the app counts as an interaction, so nothing fires in the
    // first moments of a session before the player has had a chance to act.
    _last = _clock();
  }

  /// The app-wide tracker, installed from `main()`.
  static final instance = UserActivityTracker();

  final DateTime Function() _clock;
  late DateTime _last;
  bool _installed = false;

  DateTime get lastInteraction => _last;

  void markInteraction() => _last = _clock();

  /// Hooks the global pointer route and the hardware keyboard. Needs an
  /// initialised binding; safe to call more than once.
  void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent ||
        event is PointerScrollEvent ||
        event is PointerPanZoomStartEvent) {
      markInteraction();
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) markInteraction();
    return false; // Observe only; never consume.
  }
}
