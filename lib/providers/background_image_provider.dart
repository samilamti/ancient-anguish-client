import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_state_provider.dart';
import 'unified_area_config_provider.dart';

/// Provides the current background image path for the active area, or null.
///
/// Watches the game state for area changes and resolves the image path
/// from the [UnifiedAreaConfigManager].
final backgroundImageProvider = Provider<String?>((ref) {
  final gameState = ref.watch(gameStateProvider);
  final manager = ref.watch(unifiedAreaConfigProvider).value;
  if (manager == null) return null;
  final area = gameState.currentArea;
  if (area == null) return null;
  return manager.getBackgroundForArea(area);
});
