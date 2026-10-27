import 'package:flutter/widgets.dart' show FocusNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// Keyboard play mode, the WoW chat model from design/keyboard-play-mode.md.
enum PlayMode {
  /// Today's behaviour: the input bar has focus and every key types.
  off,

  /// Keys move, fire bar slots and cycle targets; the input is closed.
  play,

  /// Play mode with the input opened by Enter. Sending the line, or Esc on
  /// an empty input, goes back to [play].
  input;

  bool get isOn => this != off;
}

final playModeProvider =
    NotifierProvider<PlayModeNotifier, PlayMode>(PlayModeNotifier.new);

/// Owns the three play-mode states. Only on/off is persisted (in
/// `AppSettings.playModeEnabled`); a relaunch always comes back closed.
class PlayModeNotifier extends Notifier<PlayMode> {
  @override
  PlayMode build() {
    // Settings load from disk after startup, so follow them rather than
    // trusting the first read.
    ref.listen<bool>(settingsProvider.select((s) => s.playModeEnabled),
        (_, enabled) {
      if (!enabled) {
        state = PlayMode.off;
      } else if (state == PlayMode.off) {
        state = PlayMode.play;
      }
    });
    return ref.read(settingsProvider).playModeEnabled
        ? PlayMode.play
        : PlayMode.off;
  }

  /// Ctrl/Cmd+G and the toolbar toggle.
  void toggle() => setEnabled(!state.isOn);

  void setEnabled(bool enabled) {
    state = enabled ? PlayMode.play : PlayMode.off;
    ref.read(settingsProvider.notifier).setPlayModeEnabled(enabled);
  }

  /// Enter in play mode.
  void openInput() {
    if (state == PlayMode.play) state = PlayMode.input;
  }

  /// The line was sent, or Esc on an empty input.
  void closeInput() {
    if (state == PlayMode.input) state = PlayMode.play;
  }
}

/// The node the play-mode key handler holds while the input is closed.
/// Shared so a tap on the terminal can hand focus back to it.
final playModeFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'play mode');
  ref.onDispose(node.dispose);
  return node;
});

/// Bumped when a key that does nothing in play mode is pressed, so the strip
/// can flash "Enter to type". The value is only a deduper.
final playStripFlashProvider =
    NotifierProvider<PlayStripFlashNotifier, int>(PlayStripFlashNotifier.new);

class PlayStripFlashNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void flash() => state++;
}
