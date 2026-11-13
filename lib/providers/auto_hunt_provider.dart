import 'dart:async';

import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hunt/auto_hunt_engine.dart';
import 'alias_provider.dart';
import 'battle_provider.dart';
import 'connection_provider.dart';
import 'local_features_provider.dart';
import 'notification_provider.dart';
import 'settings_provider.dart';

/// What the Auto Hunt toggle and its settings screen show.
class AutoHuntState {
  const AutoHuntState({this.running = false, this.status = 'Off'});

  final bool running;
  final String status;
}

/// Auto Hunt: a local-only feature (same marker asset as command triggers)
/// that walks the character n/s/e/w, attacks creatures on the target list
/// and leaves rooms holding anything on the avoid list. Never persisted as
/// running: every launch starts with it off.
final autoHuntProvider =
    NotifierProvider<AutoHuntNotifier, AutoHuntState>(AutoHuntNotifier.new);

class AutoHuntNotifier extends Notifier<AutoHuntState> {
  /// How often the engine is asked for its next move.
  static const tickInterval = Duration(milliseconds: 500);

  AutoHuntEngine? _engine;
  Timer? _timer;

  /// Fires once the MUD has been quiet for [quietGap]: the room just printed
  /// is complete and goes to the engine.
  Timer? _quiet;

  /// Long enough for one room's output split over a few packets, short
  /// against the engine's one-second pause before attacking.
  static const quietGap = Duration(milliseconds: 300);

  RoomBlockReader _reader = RoomBlockReader();

  @override
  AutoHuntState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _quiet?.cancel();
    });
    ref.listen<AppSettings>(settingsProvider, (_, s) {
      _engine?.configure(
        targets: s.autoHuntTargets,
        avoid: s.autoHuntAvoid,
        stepDelay: Duration(seconds: s.autoHuntStepSeconds),
      );
    });
    return const AutoHuntState();
  }

  void toggle() => state.running ? stop() : start();

  void start() {
    if (state.running) return;
    if (ref.read(localFeaturesAvailableProvider).value != true) return;
    final s = ref.read(settingsProvider);
    if (s.autoHuntTargets.isEmpty) {
      // Open the window so the target can be added right there.
      ref.read(autoHuntWindowProvider.notifier).open();
      ref
          .read(appNotificationsProvider.notifier)
          .show('Auto Hunt: add a target first');
      return;
    }
    _engine = AutoHuntEngine(
      targets: s.autoHuntTargets,
      avoid: s.autoHuntAvoid,
      stepDelay: Duration(seconds: s.autoHuntStepSeconds),
    );
    _reader = RoomBlockReader();
    _timer = Timer.periodic(tickInterval, (_) => _tick());
    state = const AutoHuntState(running: true, status: 'Starting');
    // Its settings stay in view for as long as it runs.
    ref.read(autoHuntWindowProvider.notifier).open();
  }

  void stop({String? reason}) {
    _timer?.cancel();
    _timer = null;
    _quiet?.cancel();
    _quiet = null;
    _engine = null;
    if (!state.running) return;
    state = AutoHuntState(status: reason ?? 'Off');
    if (reason != null) {
      ref
          .read(appNotificationsProvider.notifier)
          .show('Auto Hunt stopped: $reason');
    }
  }

  /// One plain-text line of MUD output. Cheap when Auto Hunt is off.
  void onLine(String plainText) {
    final engine = _engine;
    if (engine == null) return;
    final room = _reader.feed(plainText);
    if (room != null) engine.onRoom(room, DateTime.now());
    _quiet?.cancel();
    _quiet = Timer(quietGap, () {
      _quiet = null;
      final pending = _reader.flush();
      if (pending != null) _engine?.onRoom(pending, DateTime.now());
    });
  }

  void _tick() {
    final engine = _engine;
    if (engine == null) return;
    final command = engine.tick(
      now: DateTime.now(),
      inCombat: ref.read(battleStateProvider).inBattle,
    );
    if (engine.stuck) {
      stop(reason: engine.status);
      return;
    }
    if (command != null) _send(command);
    if (state.status != engine.status) {
      state = AutoHuntState(running: true, status: engine.status);
    }
  }

  void _send(String command) {
    final service = ref.read(connectionServiceProvider);
    for (final outgoing in ref.read(aliasEngineProvider).expand(command)) {
      if (outgoing.trim().isNotEmpty) service.sendCommand(outgoing);
    }
  }
}

/// The floating Auto Hunt window: open or not, and where it was dragged.
/// Session only; a relaunch starts closed at the default spot.
class AutoHuntWindowState {
  const AutoHuntWindowState({this.open = false, this.position = defaultPosition});

  static const defaultPosition = Offset(16, 72);

  final bool open;
  final Offset position;
}

final autoHuntWindowProvider =
    NotifierProvider<AutoHuntWindowNotifier, AutoHuntWindowState>(
        AutoHuntWindowNotifier.new);

class AutoHuntWindowNotifier extends Notifier<AutoHuntWindowState> {
  @override
  AutoHuntWindowState build() => const AutoHuntWindowState();

  void open() =>
      state = AutoHuntWindowState(open: true, position: state.position);

  /// Closing the window while hunting also stops the hunt: the settings are
  /// meant to be on screen whenever it runs.
  void close() {
    ref.read(autoHuntProvider.notifier).stop();
    state = AutoHuntWindowState(position: state.position);
  }

  void moveBy(Offset delta) => state =
      AutoHuntWindowState(open: state.open, position: state.position + delta);
}
