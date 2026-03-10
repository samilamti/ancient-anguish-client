import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/game_state_provider.dart';

/// Compact coordinate display showing the player's current position.
///
/// Shows `AreaName (x, y)` if coordinates match an entry in the area config,
/// or just `(x, y)` otherwise. Hidden when no coordinates are available.
class CoordinateDisplay extends ConsumerWidget {
  const CoordinateDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final theme = Theme.of(context);

    if (!gameState.hasCoordinates) return const SizedBox.shrink();

    final coordText = '(${gameState.x}, ${gameState.y})';
    final displayText = gameState.currentArea != null
        ? '${gameState.currentArea} $coordText'
        : coordText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(200),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withAlpha(30),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.explore,
            size: 14,
            color: theme.colorScheme.primary.withAlpha(160),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              displayText,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
