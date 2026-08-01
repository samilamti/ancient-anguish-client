import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/battle_stats.dart';
import 'package:ancient_anguish_client/models/game_state.dart';
import 'package:ancient_anguish_client/models/health_tempo.dart';
import 'package:ancient_anguish_client/providers/audio_provider.dart';
import 'package:ancient_anguish_client/providers/battle_stats_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/audio/audio_interface.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/parser/battle_text_classifier.dart';

/// Records what the audio layer was asked to do, without a sound engine.
class _RecordingAudioService implements AudioInterface {
  final List<String> played = [];
  final List<double> speeds = [];

  @override
  double masterVolume = 0.7;

  @override
  bool isMuted = false;

  @override
  bool isPlaying = false;

  @override
  String? currentTrackPath;

  @override
  VoidCallback? onTrackFinished;

  @override
  double playbackSpeed = 1.0;

  @override
  Future<void> play(
    String filePath, {
    double volume = 0.7,
    bool looping = true,
    int fadeInMs = 500,
    int fadeOutMs = 500,
  }) async {
    played.add(filePath);
    currentTrackPath = filePath;
    isPlaying = true;
  }

  @override
  Future<void> stop() async => isPlaying = false;

  @override
  Future<void> fadeOutAndStop({int fadeOutMs = 500}) async => isPlaying = false;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  void setMasterVolume(double volume) => masterVolume = volume;

  @override
  void toggleMute() => isMuted = !isMuted;

  @override
  void setMuted(bool muted) => isMuted = muted;

  @override
  void setPlaybackSpeed(double speed) {
    playbackSpeed = speed;
    speeds.add(speed);
  }

  @override
  Future<bool> canPlay(String path) async => true;

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingAudioService audio;
  late ProviderContainer container;

  setUp(() {
    audio = _RecordingAudioService();
    container = ProviderContainer(overrides: [
      audioServiceProvider.overrideWithValue(audio),
      // Both resolved up front: the manager provider rebuilds as they land,
      // and a rebuild would discard the battle themes loaded into it.
      areaDetectorProvider.overrideWith((ref) => Future.value(AreaDetector())),
      unifiedAreaConfigProvider
          .overrideWith((ref) => Future.value(UnifiedAreaConfigManager())),
    ]);
    addTearDown(container.dispose);
    // Attach the notifier so its listeners are registered.
    container.read(audioUiStateProvider.notifier);
  });

  /// Feeds one classified combat line, as the terminal buffer does.
  void combatLine(String line, {bool startsRound = true}) {
    final match = BattleTextClassifier.classify(line);
    expect(match, isNotNull, reason: 'not classified: $line');
    container
        .read(battleStatsProvider.notifier)
        .record(match!, rawLine: line, startsRound: startsRound);
  }

  void vitals({required int hp, required int maxHp}) {
    container.read(gameStateProvider.notifier).state =
        GameState(hp: hp, maxHp: maxHp);
  }

  group('battle music waits for the HUD', () {
    setUp(() async {
      // Let both async dependencies land first — the manager provider rebuilds
      // as each resolves, and a rebuild drops whatever was loaded into it.
      await container.read(areaDetectorProvider.future);
      await container.read(unifiedAreaConfigProvider.future);
      container
          .read(areaAudioManagerProvider)
          .loadBattleThemes(['/themes/battle.mp3']);
    });

    test('a stray swing or two starts nothing', () async {
      combatLine("Nurse pounded your head heartlessly.");
      combatLine('Nurse missed you.');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(battleStatsProvider).hudVisible, isFalse);
      expect(audio.played, isEmpty,
          reason: 'the panel never appeared, so neither should the theme');
    });

    test('the theme starts on the round that raises the panel', () async {
      for (var i = 0; i < BattleStats.confirmRounds; i++) {
        combatLine("You pounded Nurse's head heartlessly.");
      }
      await Future<void>.delayed(Duration.zero);

      expect(container.read(battleStatsProvider).hudVisible, isTrue);
      expect(audio.played, ['/themes/battle.mp3']);
    });
  });

  group('the soundtrack speeds up as health falls', () {
    test('each threshold steps the tempo up', () {
      vitals(hp: 100, maxHp: 100);
      expect(audio.speeds, isEmpty, reason: 'full health is the normal speed');

      vitals(hp: 70, maxHp: 100);
      expect(audio.playbackSpeed, HealthTempo.pressed.speed);

      vitals(hp: 45, maxHp: 100);
      expect(audio.playbackSpeed, HealthTempo.urgent.speed);

      vitals(hp: 30, maxHp: 100);
      expect(audio.playbackSpeed, HealthTempo.desperate.speed);

      expect(audio.speeds, hasLength(3), reason: 'one change per threshold');
    });

    test('healing walks it back down', () {
      vitals(hp: 30, maxHp: 100);
      vitals(hp: 90, maxHp: 100);
      expect(audio.playbackSpeed, HealthTempo.calm.speed);
    });

    test('HP hovering on a threshold does not flap the tempo', () {
      vitals(hp: 74, maxHp: 100);
      expect(audio.playbackSpeed, HealthTempo.pressed.speed);

      // Back over 75% but inside the release margin — still pressed.
      vitals(hp: 76, maxHp: 100);
      expect(audio.playbackSpeed, HealthTempo.pressed.speed);
      expect(audio.speeds, hasLength(1));

      vitals(hp: 80, maxHp: 100);
      expect(audio.playbackSpeed, HealthTempo.calm.speed);
    });

    test('a state with no vitals yet is not read as nearly dead', () {
      // Before the first prompt `maxHp` is zero, and `hpFraction` is 0.0.
      container.read(gameStateProvider.notifier).state = const GameState();
      expect(audio.speeds, isEmpty);
    });
  });
}
