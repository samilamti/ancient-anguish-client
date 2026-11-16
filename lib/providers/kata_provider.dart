import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/battle_stats.dart';
import '../services/kata/kata_engine.dart';
import '../services/parser/battle_text_classifier.dart';
import 'alias_provider.dart';
import 'battle_stats_provider.dart';
import 'connection_provider.dart';
import 'local_features_provider.dart';
import 'notification_provider.dart';
import 'settings_provider.dart';

/// What the Katas toggle and window show.
class KataState {
  const KataState({this.armed = false, this.performing = false, this.slot = 0});

  /// Katas are switched on: the next fight runs the sequence.
  final bool armed;

  /// A fight is on and the sequence is running.
  final bool performing;

  /// The 1-based slot fired most recently, 0 when none has fired this fight.
  final int slot;
}

/// Katas: a local-only feature (same marker asset as command triggers). The
/// player fills up to ten slots; once armed, every fight runs slot 1 at its
/// first blow, slot 2 a second later and so on, starting over after the last
/// action until the fight ends. Never persisted as armed: every launch starts
/// with it off, while the slots themselves are saved in settings.
final kataProvider = NotifierProvider<KataNotifier, KataState>(KataNotifier.new);

class KataNotifier extends Notifier<KataState> {
  static const stepInterval = Duration(seconds: 1);

  KataEngine? _engine;
  Timer? _timer;

  @override
  KataState build() {
    ref.onDispose(() => _timer?.cancel());
    // Backup end of fight: combat output has been quiet for the battle
    // timeout. A kill or death line usually ends it sooner (see [onCombatLine]).
    ref.listen<BattleStats>(battleStatsProvider, (prev, next) {
      if (!next.active) _endFight();
    });
    return const KataState();
  }

  void toggle() => state.armed ? disarm() : arm();

  void arm() {
    if (state.armed) return;
    if (ref.read(localFeaturesAvailableProvider).value != true) return;
    if (KataEngine(ref.read(settingsProvider).kataSlots).isEmpty) {
      ref.read(kataWindowProvider.notifier).open();
      ref
          .read(appNotificationsProvider.notifier)
          .show('Katas: fill in at least one action first');
      return;
    }
    state = const KataState(armed: true);
  }

  void disarm({String? reason}) {
    _endFight();
    if (!state.armed) return;
    state = const KataState();
    if (reason != null) {
      ref.read(appNotificationsProvider.notifier).show('Katas off: $reason');
    }
  }

  /// One classified combat line. Cheap when Katas are off.
  void onCombatLine(BattleLineKind kind) {
    if (!state.armed) return;
    if (kind == BattleLineKind.resolution) {
      // Somebody died. If more creatures keep fighting, their next blow
      // starts the Kata again from slot 1.
      _endFight();
      return;
    }
    if (_engine == null && KataEngine.startsFight(kind)) _startFight();
  }

  void _startFight() {
    // Read the slots now, so edits made between fights take effect.
    final engine = KataEngine(ref.read(settingsProvider).kataSlots);
    if (engine.isEmpty) return;
    _engine = engine;
    _fire();
    _timer = Timer.periodic(stepInterval, (_) => _fire());
  }

  void _fire() {
    final engine = _engine;
    if (engine == null) return;
    final slot = engine.nextSlot;
    final command = engine.next();
    if (command != null) _send(command);
    state = KataState(armed: true, performing: true, slot: slot);
  }

  void _endFight() {
    _timer?.cancel();
    _timer = null;
    _engine = null;
    if (state.performing) state = KataState(armed: state.armed);
  }

  void _send(String command) {
    final service = ref.read(connectionServiceProvider);
    for (final outgoing in ref.read(aliasEngineProvider).expand(command)) {
      if (outgoing.trim().isNotEmpty) service.sendCommand(outgoing);
    }
  }
}

/// The floating Katas window: open or not, and where it was dragged.
/// Session only; a relaunch starts closed at the default spot.
class KataWindowState {
  const KataWindowState({this.open = false, this.position = defaultPosition});

  static const defaultPosition = Offset(48, 96);

  final bool open;
  final Offset position;
}

final kataWindowProvider =
    NotifierProvider<KataWindowNotifier, KataWindowState>(
        KataWindowNotifier.new);

class KataWindowNotifier extends Notifier<KataWindowState> {
  @override
  KataWindowState build() => const KataWindowState();

  void open() => state = KataWindowState(open: true, position: state.position);

  /// Closing only hides the window: an armed Kata keeps working, which is
  /// the point of setting one up.
  void close() => state = KataWindowState(position: state.position);

  void moveBy(Offset delta) => state =
      KataWindowState(open: state.open, position: state.position + delta);
}
