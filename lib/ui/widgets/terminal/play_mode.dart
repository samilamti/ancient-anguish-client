import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connection_provider.dart'
    show connectionServiceProvider, terminalBufferProvider;
import '../../../providers/game_state_provider.dart';
import '../../../providers/link_command_provider.dart';
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
/// Returns the commands it sent, for the key overlay.
typedef ActionSlotRunner = List<String> Function(WidgetRef ref, int slot);

/// Holds keyboard focus while play mode is on and the input is closed, and
/// turns keys into moves, bar slots and targeting. Holding a movement key
/// walks (each OS key repeat sends the move again); every other key is one
/// dispatch, so holding 1 does not spam a macro.
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

  void _move(LogicalKeyboardKey key, String direction) {
    ref.read(connectionServiceProvider).sendCommand(direction);
    ref.read(gameStateProvider.notifier).recordDirectionalAttempt(direction);
    _announce(key.keyLabel, [direction]);
  }

  /// Feeds the key overlay; it checks the setting itself.
  void _announce(String key, Iterable<String> commands) =>
      ref.read(playKeyPressProvider.notifier).show(key, commands);

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

  /// T: attacks the current target, exactly as clicking its red kill link
  /// would (alias-expanded, into history). One press, one `kill`.
  void _killTarget() {
    final target = ref.read(targetProvider);
    if (target == null) {
      ref
          .read(terminalBufferProvider.notifier)
          .addLocalLine('No target.', isError: true);
      return;
    }
    ref.read(linkCommandSenderProvider)('kill $target');
    _announce('T', ['kill $target']);
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
        key == LogicalKeyboardKey.keyT ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;

    final move = playModeMovementKeys[key];
    // Held movement keys walk; anything else held never repeats an action.
    if (event is KeyRepeatEvent && move == null) {
      return mapped ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    if (move != null) {
      _move(key, move);
      return KeyEventResult.handled;
    }
    final slot = playModeSlotKeys[key];
    if (slot != null) {
      final sent = widget.onSlot?.call(ref, slot);
      if (sent != null) _announce(key.keyLabel, sent);
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
    // T kills the target; Shift+T ignores it, like X.
    if (key == LogicalKeyboardKey.keyT) {
      keys.isShiftPressed ? _ignoreTarget() : _killTarget();
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
      'PLAY · WASD move · 1–0 bar · Tab target · T kill · Enter to type';

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

/// Shows the last play-mode key and what it sent, translucent, in the middle
/// of the output: `W  north`. Each press restarts it; it holds briefly and
/// fades. Never takes a pointer, so clicks reach the links underneath.
class PlayKeyOverlay extends ConsumerStatefulWidget {
  const PlayKeyOverlay({super.key});

  /// Fully shown for the first part of [duration], then fades out.
  static const duration = Duration(milliseconds: 1100);

  @override
  ConsumerState<PlayKeyOverlay> createState() => _PlayKeyOverlayState();
}

class _PlayKeyOverlayState extends ConsumerState<PlayKeyOverlay>
    with SingleTickerProviderStateMixin {
  // Created in initState, not lazily: a lazy one would first be built in
  // dispose when no key was ever pressed, after the ticker's context is gone.
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: PlayKeyOverlay.duration);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlayKeyPress?>(playKeyPressProvider, (_, next) {
      if (next != null) _fade.forward(from: 0);
    });
    final press = ref.watch(playKeyPressProvider);
    final enabled =
        ref.watch(settingsProvider.select((s) => s.playModeKeyOverlay));
    final on = ref.watch(playModeProvider.select((m) => m.isOn));
    if (press == null || !enabled || !on) return const SizedBox.shrink();

    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _fade,
          builder: (context, child) {
            // Hold for 60%, then fade. Hidden until the first forward().
            final t = _fade.value;
            final opacity = !_fade.isAnimating && t == 0
                ? 0.0
                : t < 0.6
                    ? 1.0
                    : 1 - (t - 0.6) / 0.4;
            return Opacity(opacity: opacity, child: child);
          },
          child: _KeyCard(press: press),
        ),
      ),
    );
  }
}

class _KeyCard extends StatelessWidget {
  final PlayKeyPress press;

  const _KeyCard({required this.press});

  @override
  Widget build(BuildContext context) {
    const green = PlayModeStrip.green;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: green.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: green.withAlpha(60),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: green.withAlpha(200)),
            ),
            child: Text(
              press.key,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              press.command,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 20,
                color: Colors.white.withAlpha(230),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
