import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../models/prompt_element.dart';
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
  /// Updates all fields present in the parsed prompt values map.
  /// Uses the exact coordinate config for area name lookup.
  /// Preserves existing values for fields not included in the current prompt.
  void updateFromPrompt(Map<PromptElementId, dynamic> values) {
    final hp = values[PromptElementId.hp] as int? ?? state.hp;
    final maxHp = values[PromptElementId.maxHp] as int? ?? state.maxHp;
    final sp = values[PromptElementId.sp] as int? ?? state.sp;
    final maxSp = values[PromptElementId.maxSp] as int? ?? state.maxSp;
    final x = values[PromptElementId.xCoord] as int? ?? state.x;
    final y = values[PromptElementId.yCoord] as int? ?? state.y;

    final coordsChanged = x != state.x || y != state.y;

    // Only re-resolve area from coordinates when position actually changed.
    String? area;
    if (coordsChanged && x != null && y != null) {
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
      playerName: (values[PromptElementId.name] as String?) ?? state.playerName,
      playerClass:
          (values[PromptElementId.playerClass] as String?) ?? state.playerClass,
      race: (values[PromptElementId.race] as String?) ?? state.race,
      level: (values[PromptElementId.level] as int?) ?? state.level,
      age: (values[PromptElementId.age] as int?) ?? state.age,
      xp: (values[PromptElementId.xp] as int?) ?? state.xp,
      xpPerMin: (values[PromptElementId.xpPerMin] as int?) ?? state.xpPerMin,
      sessionXp: (values[PromptElementId.sessionXp] as int?) ?? state.sessionXp,
      sessionXpPerMin: (values[PromptElementId.sessionXpPerMin] as int?) ??
          state.sessionXpPerMin,
      aim: (values[PromptElementId.aim] as String?) ?? state.aim,
      attack: (values[PromptElementId.attack] as String?) ?? state.attack,
      defend: (values[PromptElementId.defend] as String?) ?? state.defend,
      wimpy: (values[PromptElementId.wimpy] as int?) ?? state.wimpy,
      wimpyDir: (values[PromptElementId.wimpyDir] as String?) ?? state.wimpyDir,
      coins: (values[PromptElementId.coins] as int?) ?? state.coins,
      banks: (values[PromptElementId.banks] as int?) ?? state.banks,
      gametime: (values[PromptElementId.gametime] as String?) ?? state.gametime,
      reboot: (values[PromptElementId.reboot] as String?) ?? state.reboot,
      port: (values[PromptElementId.port] as int?) ?? state.port,
      stuffed: (values[PromptElementId.stuffed] as int?) ?? state.stuffed,
      thirst: (values[PromptElementId.thirst] as int?) ?? state.thirst,
      drunk: (values[PromptElementId.drunk] as int?) ?? state.drunk,
      smoke: (values[PromptElementId.smoke] as int?) ?? state.smoke,
      med: (values[PromptElementId.med] as int?) ?? state.med,
      encumbered:
          (values[PromptElementId.encumbered] as int?) ?? state.encumbered,
      poison: (values[PromptElementId.poison] as int?) ?? state.poison,
      alignment: (values[PromptElementId.alignment] as int?) ?? state.alignment,
      hpPercent: (values[PromptElementId.hpPercent] as int?) ?? state.hpPercent,
      spPercent: (values[PromptElementId.spPercent] as int?) ?? state.spPercent,
      followers: (values[PromptElementId.followers] as int?) ?? state.followers,
      following:
          (values[PromptElementId.following] as String?) ?? state.following,
      currentArea: area,
      directionalMovesAtSameCoords:
          coordsChanged ? 0 : state.directionalMovesAtSameCoords,
    );
  }

  /// Backward-compatible wrapper for code that only has core vitals.
  void updateVitalsAndCoordinates(
    int hp, int maxHp, int sp, int maxSp, int x, int y,
  ) {
    updateFromPrompt({
      PromptElementId.hp: hp,
      PromptElementId.maxHp: maxHp,
      PromptElementId.sp: sp,
      PromptElementId.maxSp: maxSp,
      PromptElementId.xCoord: x,
      PromptElementId.yCoord: y,
    });
  }

  /// Called with room description text for text-based area detection fallback.
  ///
  /// Only applies when coordinates are unavailable. When coordinates are
  /// present, area resolution is handled exclusively by the coordinate lookup
  /// in [updateVitalsAndCoordinates] so that unmapped coordinates can be
  /// detected and offered for naming.
  void processRoomText(String roomText) {
    if (state.hasCoordinates) return;
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

  /// Records a directional movement attempt at unchanged coordinates.
  ///
  /// Only increments the counter if [command] is a recognized directional
  /// command (n, ne, north, etc.). Non-directional commands are ignored.
  void recordDirectionalAttempt(String command) {
    final normalized = command.trim().toLowerCase();
    if (!GameState.directionalCommands.contains(normalized)) return;
    state = state.copyWith(
      directionalMovesAtSameCoords: state.directionalMovesAtSameCoords + 1,
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
