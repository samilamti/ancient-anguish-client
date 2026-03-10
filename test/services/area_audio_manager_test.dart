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

  group('AreaAudioManager', () {
    test('starts enabled with no current area', () {
      expect(manager.isEnabled, true);
      expect(manager.currentPlayingArea, isNull);
    });

    test('setEnabled(false) disables area audio', () {
      manager.setEnabled(false);
      expect(manager.isEnabled, false);
    });

    test('onAreaChanged updates currentPlayingArea', () async {
      // No user track mapped, so it won't actually play, but area updates.
      await manager.onAreaChanged('Tantallon');
      expect(manager.currentPlayingArea, 'Tantallon');
    });

    test('same area change is a no-op', () async {
      await manager.onAreaChanged('Tantallon');
      await manager.onAreaChanged('Tantallon'); // Should not error.
      expect(manager.currentPlayingArea, 'Tantallon');
    });

    test('disabled manager ignores area changes', () async {
      manager.setEnabled(false);
      await manager.onAreaChanged('Tantallon');
      expect(manager.currentPlayingArea, isNull);
    });

    test('user track map management', () {
      manager.setTrackForArea('Tantallon', '/audio/town.mp3');
      expect(manager.userTrackMap['Tantallon'], '/audio/town.mp3');

      manager.removeTrackForArea('Tantallon');
      expect(manager.userTrackMap.containsKey('Tantallon'), false);
    });

    test('loadUserTrackMap replaces existing mappings', () {
      manager.setTrackForArea('Old', '/old.mp3');
      manager.loadUserTrackMap({'New': '/new.mp3'});
      expect(manager.userTrackMap.containsKey('Old'), false);
      expect(manager.userTrackMap['New'], '/new.mp3');
    });

    test('reset clears state', () async {
      await manager.onAreaChanged('Tantallon');
      await manager.reset();
      expect(manager.currentPlayingArea, isNull);
    });
  });
}
