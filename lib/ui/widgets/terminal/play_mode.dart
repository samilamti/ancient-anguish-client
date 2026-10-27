import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connection_provider.dart' show connectionServiceProvider;
import '../../../providers/game_state_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/play_mode_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/target_provider.dart';

/// Play-mode movement keys. Full words, as the D-pad sends them.
final Map<LogicalKeyboardKey, String> playModeMovementKeys = {
  LogicalKeyboardKey.keyW: 'north',
  LogicalKeyboardKey.keyA: 'west',
  LogicalKeyboardKey.keyS: 'south',
  LogicalKeyboardKey.keyD: 'east',
  LogicalKeyboardKey.keyQ: 'northwest',
  LogicalKeyboardKey.keyE: 'northeast',
  LogicalKeyboardKey.keyZ: 'southwest',
  LogicalKeyboardKey.keyC: 'southeast',
  LogicalKeyboardKey.keyR: 'up',
  LogicalKeyboardKey.keyF: 'down',
};

/// Digit keys 1…9, 0 → action bar slots 0…9.
final Map<LogicalKeyboardKey, int> playModeSlotKeys = {
  LogicalKeyboardKey.digit1: 0,
  LogicalKeyboardKey.digit2: 1,
  LogicalKeyboardKey.digit3: 2,
  LogicalKeyboardKey.digit4: 3,
  LogicalKeyboardKey.digit5: 4,
  LogicalKeyboardKey.digit6: 5,
  LogicalKeyboardKey.digit7: 6,
  LogicalKeyboardKey.digit8: 7,
  LogicalKeyboardKey.digit9: 8,
  LogicalKeyboardKey.digit0: 9,
};

/// Signature of the action-bar dispatcher the key handler calls for 1…0.
typedef ActionSlotRunner = void Function(WidgetRef ref, int slot);

/// Holds keyboard focus while play mode is on and the input is closed, and
/// turns keys into moves, bar slots and targeting. Every key is one dispatch:
/// key repeat is dropped, so holding W does not run through ten rooms.
///
/// Anything with Ctrl/Cmd (or Alt) is left alone so the HomeScreen chords
/// still bubble up, and nothing is handled while a text field holds focus.
class PlayModeKeys extends ConsumerStatefulWidget {
  final Widget child;

  /// False below the phone breakpoint: no play mode there.
  final bool available;

  /// Fires action bar slot `n` (0-based). Null until the bar exists.
  final ActionSlotRunner? onSlot;

  const PlayModeKeys({
    super.key,
    required this.child,
    required this.available,
    this.onSlot,
  });

  @override
  ConsumerState<PlayModeKeys> createState() => _PlayModeKeysState();
}

class _PlayModeKeysState extends ConsumerState<PlayModeKeys> {
  late final FocusNode _node = ref.read(playModeFocusProvider);

  bool get _active =>
      widget.available && ref.read(playModeProvider) == PlayMode.play;

  /// Takes focus back unless the player is typing somewhere else (a chat
  /// input, the Notes editor).
  void _claimFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_active || _node.hasPrimaryFocus) return;
      if (_isTyping(FocusManager.instance.primaryFocus)) return;
      _node.requestFocus();
    });
  }

  static bool _isTyping(FocusNode? node) =>
      node?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

  void _move(String direction) {
    ref.read(connectionServiceProvider).sendCommand(direction);
    ref.read(gameStateProvider.notifier).recordDirectionalAttempt(direction);
  }

  void _ignoreTarget() {
    final keyword = ref.read(targetProvider.notifier).ignoreCurrent();
    if (keyword == null) return;
    ref.read(appNotificationsProvider.notifier).show(
          "Ignoring '$keyword'",
          actionLabel: 'Undo',
          onAction: () => ref
              .read(settingsProvider.notifier)
              .removeIgnoredKillTarget(keyword),
        );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_active || !node.hasPrimaryFocus) return KeyEventResult.ignored;
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed || keys.isAltPressed) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final mapped = playModeMovementKeys.containsKey(key) ||
        playModeSlotKeys.containsKey(key) ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.keyX ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;

    // Held keys never repeat an action.
    if (event is KeyRepeatEvent) {
      return mapped ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    final move = playModeMovementKeys[key];
    if (move != null) {
      _move(move);
      return KeyEventResult.handled;
    }
    final slot = playModeSlotKeys[key];
    if (slot != null) {
      widget.onSlot?.call(ref, slot);
      return KeyEventResult.handled;
    }
    final target = ref.read(targetProvider.notifier);
    if (key == LogicalKeyboardKey.tab) {
      keys.isShiftPressed ? target.previous() : target.next();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX) {
      _ignoreTarget();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      target.clear();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      ref.read(playModeProvider.notifier).openInput();
      return KeyEventResult.handled;
    }

    // A printable key that does nothing here: remind, don't send.
    final character = event.character;
    if (character != null && character.trim().isNotEmpty) {
      ref.read(playStripFlashProvider.notifier).flash();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlayMode>(playModeProvider, (_, next) {
      if (next == PlayMode.play) _claimFocus();
    });
    if (_active) _claimFocus();
    return Focus(
      focusNode: _node,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}

/// Green-outlined strip that stands in for the closed input in play mode.
/// Clicking it opens the input, like Enter.
class PlayModeStrip extends ConsumerStatefulWidget {
  const PlayModeStrip({super.key});

  /// The green of an active toolbar toggle.
  static const green = Color(0xFF4CAF50);

  static const text =
      'PLAY · WASD move · 1–0 bar · Tab target · Enter to type';

  @override
  ConsumerState<PlayModeStrip> createState() => _PlayModeStripState();
}

class _PlayModeStripState extends ConsumerState<PlayModeStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(playStripFlashProvider, (_, _) => _flash.forward(from: 0));
    final theme = Theme.of(context);
    final fontSize = ref.watch(settingsProvider.select((s) => s.fontSize));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(playModeProvider.notifier).openInput(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: PlayModeStrip.green, width: 1.5),
        ),
        child: AnimatedBuilder(
          animation: _flash,
          builder: (context, _) {
            // Brightens and settles back over the flash.
            final t = _flash.isAnimating ? 1 - _flash.value : 0.0;
            return Text(
              PlayModeStrip.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: fontSize,
                color: Color.lerp(
                    PlayModeStrip.green.withAlpha(200), Colors.white, t),
                fontWeight: t > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            );
          },
        ),
      ),
    );
  }
}
