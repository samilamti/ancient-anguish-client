import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../services/area/area_detector.dart';
import '../services/parser/prompt_parser.dart';
import 'coord_area_config_provider.dart';

/// Provides the [PromptParser] singleton.
final promptParserProvider = Provider<PromptParser>((ref) {
  return PromptParser();
});

/// Provides the [AreaDetector] singleton.
final areaDetectorProvider = Provider<AreaDetector>((ref) {
  final detector = AreaDetector();
  // Load area definitions asynchronously. The detector works with an empty
  // list until loading completes, so this is safe.
  detector.loadAreaDefinitions();
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
      // Preserve the current area from coordinate-based detection.
      // Area detection is handled by updateCoordinates (exact config match)
      // and processRoomText (text fallback), not here.
      state = newState.copyWith(currentArea: state.currentArea);
    }
  }

  /// Called when coordinate lines are parsed from the MUD output.
  ///
  /// Uses only the exact coordinate config for area name lookup.
  /// Constructs state directly (not via copyWith) so that currentArea can be
  /// cleared to null when no config entry matches.
  void updateCoordinates(int x, int y) {
    final coordConfig = ref.read(coordAreaConfigProvider);
    final configEntry = coordConfig.lookup(x, y);
    state = GameState(
      hp: state.hp,
      maxHp: state.maxHp,
      sp: state.sp,
      maxSp: state.maxSp,
      x: x,
      y: y,
      playerName: state.playerName,
      playerClass: state.playerClass,
      coins: state.coins,
      xp: state.xp,
      currentArea: configEntry?.areaName,
    );
  }

  /// Called with room description text for text-based area detection fallback.
  void processRoomText(String roomText) {
    final detector = ref.read(areaDetectorProvider);
    final area = detector.detect(roomText: roomText);

    if (area != state.currentArea) {
      state = state.copyWith(currentArea: area);
    }
  }

  /// Resets the game state (e.g., on disconnect).
  void reset() {
    ref.read(promptParserProvider).reset();
    ref.read(areaDetectorProvider).reset();
    state = GameState.initial;
  }
}
