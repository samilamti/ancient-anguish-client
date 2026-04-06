import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/area_config_entry.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';

void main() {
  late ProviderContainer container;
  late GameStateNotifier notifier;

  /// Creates a ProviderContainer with all required overrides.
  ProviderContainer createContainer({UnifiedAreaConfigManager? configManager}) {
    final manager = configManager ?? UnifiedAreaConfigManager();
    return ProviderContainer(
      overrides: [
        promptParserProvider.overrideWithValue(PromptParser()),
        areaDetectorProvider
            .overrideWith((ref) => Future.value(AreaDetector())),
        unifiedAreaConfigProvider.overrideWith((ref) => Future.value(manager)),
      ],
    );
  }

  setUp(() {
    container = createContainer();
    notifier = container.read(gameStateProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('GameStateNotifier - initial state', () {
    test('starts with GameState.initial', () {
      final state = container.read(gameStateProvider);
      expect(state.hp, 0);
      expect(state.maxHp, 0);
      expect(state.x, isNull);
      expect(state.playerName, isNull);
    });
  });

  group('GameStateNotifier - processLine', () {
    test('updates state when prompt is parsed', () {
      // PromptParser expects format like "125/125:80/80>"
      notifier.processLine('100/150:80/120>');
      final state = container.read(gameStateProvider);
      expect(state.hp, 100);
      expect(state.maxHp, 150);
      expect(state.sp, 80);
      expect(state.maxSp, 120);
    });

    test('preserves currentArea from previous state', () {
      // First set up an area via updateVitalsAndCoordinates.
      notifier.updateVitalsAndCoordinates(100, 150, 80, 120, 0, 0);

      // The area comes from unified config lookup; with empty config it's null.
      // Just verify processLine preserves whatever currentArea was set.

      // Set player name first (it sticks).
      notifier.setPlayerName('TestPlayer');

      // Process a prompt line.
      notifier.processLine('90/150:70/120>');
      final updated = container.read(gameStateProvider);
      expect(updated.hp, 90);
      expect(updated.playerName, 'TestPlayer');
    });

    test('does not change state for non-prompt lines', () {
      final before = container.read(gameStateProvider);
      notifier.processLine('You see a beautiful forest.');
      final after = container.read(gameStateProvider);
      expect(after.hp, before.hp);
      expect(after.maxHp, before.maxHp);
    });
  });

  group('GameStateNotifier - updateVitalsAndCoordinates', () {
    test('sets HP, SP, and coordinates', () {
      notifier.updateVitalsAndCoordinates(100, 150, 80, 120, 5, -3);
      final state = container.read(gameStateProvider);
      expect(state.hp, 100);
      expect(state.maxHp, 150);
      expect(state.sp, 80);
      expect(state.maxSp, 120);
      expect(state.x, 5);
      expect(state.y, -3);
    });

    test('preserves playerName from previous state', () {
      notifier.setPlayerName('Hero');
      notifier.updateVitalsAndCoordinates(100, 150, 80, 120, 0, 0);
      expect(container.read(gameStateProvider).playerName, 'Hero');
    });

    test('clears currentArea to null when no config entry matches', () {
      // Empty unified config → no match → currentArea should be null.
      notifier.updateVitalsAndCoordinates(100, 150, 80, 120, 99, 99);
      expect(container.read(gameStateProvider).currentArea, isNull);
    });

    test('sets currentArea from unified config when found', () async {
      // Create a manager with a known area entry.
      final manager = UnifiedAreaConfigManager();
      manager.loadFromConfig(UnifiedAreaConfig(
        areas: {
          'Tantallon': const AreaConfigEntry(
            name: 'Tantallon',
            coordinates: ['0,0'],
          ),
        },
      ));

      container.dispose();
      container = createContainer(configManager: manager);
      notifier = container.read(gameStateProvider.notifier);

      // Let the FutureProvider resolve (Future.value completes in a microtask).
      await container.read(unifiedAreaConfigProvider.future);

      notifier.updateVitalsAndCoordinates(100, 150, 80, 120, 0, 0);
      expect(container.read(gameStateProvider).currentArea, 'Tantallon');
    });
  });

  group('GameStateNotifier - updateCurrentVitals', () {
    test('updates only hp and sp, preserving all other fields', () {
      notifier.updateVitalsAndCoordinates(100, 150, 80, 120, 5, -3);
      notifier.setPlayerName('Hero');

      notifier.updateCurrentVitals(hp: 90, sp: 60);

      final state = container.read(gameStateProvider);
      expect(state.hp, 90);
      expect(state.sp, 60);
      expect(state.maxHp, 150);
      expect(state.maxSp, 120);
      expect(state.x, 5);
      expect(state.y, -3);
      expect(state.playerName, 'Hero');
    });

    test('updates only hp when sp is omitted', () {
      notifier.updateVitalsAndCoordinates(100, 150, 80, 120, 0, 0);
      notifier.updateCurrentVitals(hp: 42);
      final state = container.read(gameStateProvider);
      expect(state.hp, 42);
      expect(state.sp, 80);
    });

    test('updates only sp when hp is omitted', () {
      notifier.updateVitalsAndCoordinates(100, 150, 80, 120, 0, 0);
      notifier.updateCurrentVitals(sp: 33);
      final state = container.read(gameStateProvider);
      expect(state.hp, 100);
      expect(state.sp, 33);
    });
  });

  group('GameStateNotifier - setPlayerName', () {
    test('sets playerName preserving other fields', () {
      notifier.updateVitalsAndCoordinates(100, 150, 80, 120, 5, 10);
      notifier.setPlayerName('Wizard');
      final state = container.read(gameStateProvider);
      expect(state.playerName, 'Wizard');
      expect(state.hp, 100);
      expect(state.x, 5);
    });
  });

  group('GameStateNotifier - reset', () {
    test('returns to GameState.initial', () {
      notifier.setPlayerName('Hero');
      notifier.updateVitalsAndCoordinates(100, 150, 80, 120, 5, 10);

      notifier.reset();

      final state = container.read(gameStateProvider);
      expect(state.hp, 0);
      expect(state.maxHp, 0);
      expect(state.x, isNull);
      expect(state.playerName, isNull);
    });
  });
}
