import 'dart:async';

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
      ref
          .read(appNotificationsProvider.notifier)
          .show('Auto Hunt: add a target first (Settings → Auto Hunt)');
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
