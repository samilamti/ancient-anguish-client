import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/area_config.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/audio/area_audio_manager.dart';
import 'package:ancient_anguish_client/services/audio/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AudioService audioService;
  late AreaDetector areaDetector;
  late AreaAudioManager manager;

  setUp(() {
    audioService = AudioService();
    areaDetector = AreaDetector();
    areaDetector.loadFromList([
      const AreaConfig(
        name: 'Tantallon',
        bounds: AreaBounds(xMin: -2, xMax: 2, yMin: -2, yMax: 2),
        audio: AreaAudio(track: 'tantallon.mp3', volume: 0.7, fadeMs: 2000),
      ),
      const AreaConfig(
        name: 'Wilderness',
        bounds: AreaBounds(xMin: -10, xMax: 10, yMin: -10, yMax: 10),
      ),
    ]);

    manager = AreaAudioManager(
      audioService: audioService,
      areaDetector: areaDetector,
    );
  });

  tearDown(() async {
    await manager.dispose();
  });

  group('AreaAudioManager - Concurrency', () {
    test('setEnabled(false) is awaitable and clears state', () async {
      // setEnabled now returns Future<void>, so callers can wait for fade.
      await manager.setEnabled(false);
      expect(manager.isEnabled, false);
      expect(manager.currentPlayingArea, isNull);
    });

    test('setEnabled(true) after disable re-enables', () async {
      await manager.setEnabled(false);
      await manager.setEnabled(true);
      expect(manager.isEnabled, true);
    });

    test('concurrent onAreaChanged calls leave consistent state', () async {
      // Fire multiple area changes simultaneously.
      final f1 = manager.onAreaChanged('Tantallon');
      final f2 = manager.onAreaChanged('Wilderness');
      final f3 = manager.onAreaChanged('Tantallon');
      await Future.wait([f1, f2, f3]);

      // State should be consistent — one of the areas should have won.
      expect(manager.currentPlayingArea, isNotNull);
    });

    test('onAreaChanged after setEnabled(false) is a no-op', () async {
      await manager.setEnabled(false);
      await manager.onAreaChanged('Tantallon');
      expect(manager.currentPlayingArea, isNull);
    });

    test('rapid enable/disable cycles are safe', () async {
      for (var i = 0; i < 5; i++) {
        await manager.setEnabled(false);
        await manager.setEnabled(true);
      }
      expect(manager.isEnabled, true);
    });
  });
}
