import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background/area_background_manager.dart';
import 'game_state_provider.dart';

/// Provides the [AreaBackgroundManager] singleton.
final areaBackgroundManagerProvider = Provider<AreaBackgroundManager>((ref) {
  return AreaBackgroundManager();
});

/// Provides the current background image path for the active area, or null.
///
/// Watches the game state for area changes and resolves the image path
/// from the [AreaBackgroundManager].
final backgroundImageProvider = Provider<String?>((ref) {
  final gameState = ref.watch(gameStateProvider);
  final manager = ref.watch(areaBackgroundManagerProvider);
  final area = gameState.currentArea;
  if (area == null) return null;
  return manager.getImageForArea(area);
});
