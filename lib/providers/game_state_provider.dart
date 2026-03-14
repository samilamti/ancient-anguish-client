import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../services/area/area_detector.dart';
import '../services/parser/prompt_parser.dart';
import 'unified_area_config_provider.dart';

/// Provides the [PromptParser] singleton.
final promptParserProvider = Provider<PromptParser>((ref) {
  return PromptParser();
});

/// Provides the [AreaDetector] singleton, loading area definitions from the
/// bundled JSON asset. Consumers that `watch` this provider automatically
/// rebuild once loading completes.
final areaDetectorProvider = FutureProvider<AreaDetector>((ref) async {
  final detector = AreaDetector();
  await detector.loadAreaDefinitions();
  return detector;
});

/// Provides the current [GameState].
///
/// Updated by the terminal buffer notifier whenever a prompt line is detected.
final gameStateProvider =
    NotifierProvider<GameStateNotifier, GameState>(GameStateNotifier.new);

/// Manages the parsed game state, updating it when new prompt data arrives.
class GameStateNotifier extends Notifier<GameState> {
  @override
  GameState build() => GameState.initial;

  /// Called by the terminal buffer notifier when a new line of output arrives.
  ///
  /// Attempts to parse it as a prompt line and update the game state.
  void processLine(String plainText) {
    final parser = ref.read(promptParserProvider);
    final newState = parser.parseLine(plainText);

    if (newState != null) {
      // Preserve fields that the basic prompt parser doesn't set.
      // Area detection is handled by updateVitalsAndCoordinates (exact config match)
      // and processRoomText (text fallback), not here.
      state = newState.copyWith(
        currentArea: state.currentArea,
        playerName: newState.playerName ?? state.playerName,
        playerClass: newState.playerClass ?? state.playerClass,
        coins: newState.coins ?? state.coins,
        xp: newState.xp ?? state.xp,
      );
    }
  }

  /// Called when prompt lines are parsed from the MUD output.
  ///
  /// Updates HP, MaxHP, SP, MaxSP, and coordinates in a single state update.
  /// Uses the exact coordinate config for area name lookup.
  /// Constructs state directly (not via copyWith) so that currentArea can be
  /// cleared to null when no config entry matches.
  void updateVitalsAndCoordinates(
    int hp, int maxHp, int sp, int maxSp, int x, int y,
  ) {
    final coordsChanged = x != state.x || y != state.y;

    // Only re-resolve area from coordinates when position actually changed.
    // This preserves text-based overrides (e.g., "Inns" inside Tantallon).
    String? area;
    if (coordsChanged) {
      final unifiedConfig = ref.read(unifiedAreaConfigProvider).value;
      final configEntry = unifiedConfig?.lookupByCoord(x, y);
      area = configEntry?.name;
    } else {
      area = state.currentArea;
    }

    state = GameState(
      hp: hp,
      maxHp: maxHp,
      sp: sp,
      maxSp: maxSp,
      x: x,
      y: y,
      playerName: state.playerName,
      playerClass: state.playerClass,
      coins: state.coins,
      xp: state.xp,
      currentArea: area,
      commandsSinceCoordChange:
          coordsChanged ? 0 : state.commandsSinceCoordChange,
    );
  }

  /// Called with room description text for text-based area detection fallback.
  void processRoomText(String roomText) {
    final detector = ref.read(areaDetectorProvider).value;
    if (detector == null) return;
    final area = detector.detect(roomText: roomText);

    if (area != state.currentArea) {
      state = state.copyWith(currentArea: area);
    }
  }

  /// Updates only the current HP and/or SP, preserving all other fields.
  ///
  /// Used by the battle pattern detector which only provides current vitals.
  void updateCurrentVitals({int? hp, int? sp}) {
    state = state.copyWith(hp: hp ?? state.hp, sp: sp ?? state.sp);
  }

  /// Increments the command counter (called when a command is sent to the MUD).
  void incrementCommandCounter() {
    state = state.copyWith(
      commandsSinceCoordChange: state.commandsSinceCoordChange + 1,
    );
  }

  /// Sets the current area name directly (e.g., after the player names a new area).
  void setCurrentArea(String area) {
    state = state.copyWith(currentArea: area);
  }

  /// Sets the player name (called after login dialog submission).
  void setPlayerName(String name) {
    state = state.copyWith(playerName: name);
  }

  /// Resets the game state (e.g., on disconnect).
  void reset() {
    ref.read(promptParserProvider).reset();
    ref.read(areaDetectorProvider).value?.reset();
    state = GameState.initial;
  }
}
