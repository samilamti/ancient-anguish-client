import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/game_state_provider.dart';

/// Shows wimpy HP threshold and flee direction as a compact badge.
class WimpyIndicator extends ConsumerWidget {
  const WimpyIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
    if (gs.wimpy == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    // Color by danger level relative to max HP.
    final fraction =
        gs.maxHp > 0 ? (gs.wimpy! / gs.maxHp).clamp(0.0, 1.0) : 0.0;
    final color = fraction > 0.5
        ? const Color(0xFFCC2222)
        : fraction > 0.25
            ? const Color(0xFFCC8800)
            : const Color(0xFF44AA44);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(230),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withAlpha(40),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_run, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            'Wimpy ',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          Text(
            '${gs.wimpy} HP',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (gs.wimpyDir != null) ...[
            const SizedBox(width: 6),
            Text(
              gs.wimpyDir!,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
