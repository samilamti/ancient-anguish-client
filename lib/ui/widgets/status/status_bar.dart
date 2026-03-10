import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/game_state_provider.dart';
import 'vitals_gauge.dart';

/// HP and SP bars displayed side by side at the top of the screen.
class VitalsRow extends ConsumerWidget {
  const VitalsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final theme = Theme.of(context);

    if (!gameState.hasVitals) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(230),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withAlpha(40),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HP gauge.
          Expanded(
            child: VitalsGauge(
              label: 'HP',
              value: gameState.hp,
              maxValue: gameState.maxHp,
              icon: Icons.favorite,
              gradientColors: [
                _hpColor(gameState.hpFraction).withAlpha(180),
                _hpColor(gameState.hpFraction),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // SP gauge.
          Expanded(
            child: VitalsGauge(
              label: 'SP',
              value: gameState.sp,
              maxValue: gameState.maxSp,
              icon: Icons.auto_awesome,
              gradientColors: const [
                Color(0xFF2255AA),
                Color(0xFF4488FF),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _hpColor(double fraction) {
    if (fraction > 0.6) return const Color(0xFF44AA44);
    if (fraction > 0.3) return const Color(0xFFCC8800);
    return const Color(0xFFCC2222);
  }
}

/// Status bar showing coordinates, area, and player info.
///
/// HP/SP gauges are shown separately by [VitalsRow].
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final theme = Theme.of(context);

    // Only show when we have coordinates or player info.
    if (!gameState.hasCoordinates &&
        gameState.currentArea == null &&
        gameState.playerName == null &&
        gameState.xp == null &&
        gameState.coins == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(230),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withAlpha(40),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Info row: coordinates, area, XP.
          Row(
            children: [
              if (gameState.hasCoordinates) ...[
                Icon(Icons.explore, size: 14,
                    color: theme.colorScheme.onSurface.withAlpha(140)),
                const SizedBox(width: 4),
                Text(
                  '(${gameState.x}, ${gameState.y})',
                  style: _infoTextStyle(theme),
                ),
                const SizedBox(width: 12),
              ],
              if (gameState.currentArea != null) ...[
                Icon(Icons.map, size: 14,
                    color: theme.colorScheme.primary.withAlpha(180)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    gameState.currentArea!,
                    style: _infoTextStyle(theme).copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              if (gameState.xp != null)
                Text(
                  'XP: ${_formatNumber(gameState.xp!)}',
                  style: _infoTextStyle(theme).copyWith(
                    color: const Color(0xFFD4A057),
                  ),
                ),
            ],
          ),

          // Player info row.
          if (gameState.coins != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Spacer(),
                  Icon(Icons.monetization_on, size: 12,
                      color: const Color(0xFFD4A057).withAlpha(180)),
                  const SizedBox(width: 3),
                  Text(
                    _formatNumber(gameState.coins!),
                    style: _infoTextStyle(theme).copyWith(
                      color: const Color(0xFFD4A057),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _infoTextStyle(ThemeData theme) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 11,
      color: theme.colorScheme.onSurface.withAlpha(160),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
