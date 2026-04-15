import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/game_state_provider.dart';

/// Displays combat readiness: aim, attack style, and defense.
class CombatStatsPanel extends ConsumerWidget {
  const CombatStatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
    if (!gs.hasCombatStats) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 11,
      color: theme.colorScheme.onSurface.withAlpha(180),
    );
    final labelStyle = textStyle.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurface.withAlpha(120),
    );

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
          Icon(Icons.shield, size: 13, color: const Color(0xFFCC4444).withAlpha(200)),
          const SizedBox(width: 6),
          if (gs.aim != null) ...[
            Text('AIM ', style: labelStyle),
            Text(gs.aim!, style: textStyle),
            const SizedBox(width: 10),
          ],
          if (gs.attack != null) ...[
            Text('ATK ', style: labelStyle),
            Text(gs.attack!, style: textStyle),
            const SizedBox(width: 10),
          ],
          if (gs.defend != null) ...[
            Text('DEF ', style: labelStyle),
            Text(gs.defend!, style: textStyle),
          ],
        ],
      ),
    );
  }
}
