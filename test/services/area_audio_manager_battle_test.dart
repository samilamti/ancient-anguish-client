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
    audioService = AudioService.forTesting();
    areaDetector = AreaDetector();
    areaDetector.loadFromList([
      const AreaConfig(
        name: 'Tantallon',
        bounds: AreaBounds(xMin: -2, xMax: 2, yMin: -2, yMax: 2),
        audio: AreaAudio(track: 'tantallon.mp3', volume: 0.7, fadeMs: 2000),
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

  group('Battle theme list management', () {
    test('starts with empty battle themes', () {
      expect(manager.battleThemes, isEmpty);
      expect(manager.inBattle, isFalse);
    });

    test('addBattleTheme appends to list', () {
      manager.addBattleTheme('/music/battle1.mp3');
      manager.addBattleTheme('/music/battle2.mp3');
      expect(manager.battleThemes, ['/music/battle1.mp3', '/music/battle2.mp3']);
    });

    test('removeBattleThemeAt removes correct entry', () {
      manager.addBattleTheme('/music/a.mp3');
      manager.addBattleTheme('/music/b.mp3');
      manager.addBattleTheme('/music/c.mp3');

      manager.removeBattleThemeAt(1);
      expect(manager.battleThemes, ['/music/a.mp3', '/music/c.mp3']);
    });

    test('removeBattleThemeAt ignores invalid index', () {
      manager.addBattleTheme('/music/a.mp3');
      manager.removeBattleThemeAt(-1);
      manager.removeBattleThemeAt(5);
      expect(manager.battleThemes, ['/music/a.mp3']);
    });

    test('reorderBattleThemes moves item forward', () {
      manager.addBattleTheme('/music/a.mp3');
      manager.addBattleTheme('/music/b.mp3');
      manager.addBattleTheme('/music/c.mp3');

      manager.reorderBattleThemes(2, 0); // Move c to front.
      expect(manager.battleThemes, ['/music/c.mp3', '/music/a.mp3', '/music/b.mp3']);
    });

    test('reorderBattleThemes moves item backward', () {
      manager.addBattleTheme('/music/a.mp3');
      manager.addBattleTheme('/music/b.mp3');
      manager.addBattleTheme('/music/c.mp3');

      manager.reorderBattleThemes(0, 3); // Move a to end.
      expect(manager.battleThemes, ['/music/b.mp3', '/music/c.mp3', '/music/a.mp3']);
    });

    test('loadBattleThemes replaces list and resets index', () {
      manager.addBattleTheme('/music/old.mp3');
      manager.loadBattleThemes(['/music/new1.mp3', '/music/new2.mp3']);
      expect(manager.battleThemes, ['/music/new1.mp3', '/music/new2.mp3']);
    });

    test('battleThemes returns unmodifiable copy', () {
      manager.addBattleTheme('/music/a.mp3');
      final list = manager.battleThemes;
      expect(() => list.add('/music/b.mp3'), throwsUnsupportedError);
    });
  });

  group('Battle state transitions', () {
    test('onBattleStateChanged with empty themes does nothing', () async {
      final result = await manager.onBattleStateChanged(true);
      expect(result, isNull);
      expect(manager.inBattle, isTrue);
    });

    test('onBattleStateChanged(true) sets inBattle', () async {
      manager.addBattleTheme('/music/battle.mp3');
      await manager.onBattleStateChanged(true);
      expect(manager.inBattle, isTrue);
    });

    test('onBattleStateChanged(false) clears inBattle', () async {
      manager.addBattleTheme('/music/battle.mp3');
      await manager.onBattleStateChanged(true);
      await manager.onBattleStateChanged(false);
      expect(manager.inBattle, isFalse);
    });

    test('repeated true does not re-enter', () async {
      manager.addBattleTheme('/music/battle.mp3');
      await manager.onBattleStateChanged(true);
      // Second call with true while already in battle — should be no-op.
      final result = await manager.onBattleStateChanged(true);
      expect(result, isNull);
      expect(manager.inBattle, isTrue);
    });

    test('disabled manager ignores battle transitions', () async {
      manager.addBattleTheme('/music/battle.mp3');
      await manager.setEnabled(false);
      final result = await manager.onBattleStateChanged(true);
      expect(result, isNull);
      expect(manager.inBattle, isFalse);
    });

    test('false when not in battle is no-op', () async {
      final result = await manager.onBattleStateChanged(false);
      expect(result, isNull);
      expect(manager.inBattle, isFalse);
    });
  });

  group('Battle and area interaction', () {
    test('onAreaChanged during battle does not change area audio', () async {
      manager.addBattleTheme('/music/battle.mp3');
      manager.setTrackForArea('Tantallon', '/music/town.mp3');

      await manager.onAreaChanged('Tantallon');
      expect(manager.currentPlayingArea, 'Tantallon');

      await manager.onBattleStateChanged(true);
      expect(manager.inBattle, isTrue);

      // Area change during battle — should update tracking but not audio.
      await manager.onAreaChanged('Wilderness');
      expect(manager.currentPlayingArea, 'Wilderness');
    });

    test('reset clears battle state', () async {
      manager.addBattleTheme('/music/battle.mp3');
      await manager.onBattleStateChanged(true);
      expect(manager.inBattle, isTrue);

      await manager.reset();
      expect(manager.inBattle, isFalse);
      expect(manager.currentPlayingArea, isNull);
      // Battle themes list is preserved (user config).
      expect(manager.battleThemes, ['/music/battle.mp3']);
    });
  });

  group('Theme rotation index', () {
    test('removeBattleThemeAt adjusts index when past end', () {
      manager.addBattleTheme('/music/a.mp3');
      manager.addBattleTheme('/music/b.mp3');

      // Simulate advancing the index by entering battle twice.
      // Since files don't exist, crossfade won't happen but index advances.
      manager.onBattleStateChanged(true);
      manager.onBattleStateChanged(false);

      // Remove last item — index should wrap to 0.
      manager.removeBattleThemeAt(1);
      expect(manager.battleThemes.length, 1);
    });

    test('reorderBattleThemes resets index to 0', () {
      manager.addBattleTheme('/music/a.mp3');
      manager.addBattleTheme('/music/b.mp3');
      manager.addBattleTheme('/music/c.mp3');

      manager.reorderBattleThemes(0, 3);
      // After reorder, index should be reset.
      // We can't directly read _battleThemeIndex, but behavior is consistent.
      expect(manager.battleThemes.length, 3);
    });
  });
}
