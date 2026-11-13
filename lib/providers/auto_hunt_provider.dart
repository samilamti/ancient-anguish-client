import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hunt/auto_hunt_engine.dart';
import '../services/parser/room_line_classifier.dart';
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

  // Room block capture, the same shape RoomTargetsNotifier reads.
  List<String>? _blockExits;
  final List<String> _blockLines = [];

  @override
  AutoHuntState build() {
    ref.onDispose(() => _timer?.cancel());
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
    _blockExits = null;
    _blockLines.clear();
    _timer = Timer.periodic(tickInterval, (_) => _tick());
    state = const AutoHuntState(running: true, status: 'Starting');
  }

  void stop({String? reason}) {
    _timer?.cancel();
    _timer = null;
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
    final line = plainText.trimRight();
    final exits = RoomSighting.exitsOf(line);
    if (exits != null) {
      _finishBlock(engine);
      _blockExits = exits;
      _blockLines.clear();
      return;
    }
    if (_blockExits == null) return;
    if (line.trim().isEmpty || RoomLineClassifier.isPromptShape(line)) {
      _finishBlock(engine);
      return;
    }
    _blockLines.add(line);
  }

  void _finishBlock(AutoHuntEngine engine) {
    final exits = _blockExits;
    if (exits == null) return;
    engine.onRoom(
      RoomSighting(exits: exits, lines: List.of(_blockLines)),
      DateTime.now(),
    );
    _blockExits = null;
    _blockLines.clear();
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
