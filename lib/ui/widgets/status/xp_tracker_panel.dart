import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/game_state_provider.dart';

/// Displays XP tracking: XP/min, session XP, and session XP/min.
class XpTrackerPanel extends ConsumerWidget {
  const XpTrackerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
    if (!gs.hasXpTracking) return const SizedBox.shrink();

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
    const xpColor = Color(0xFF44BB44);

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
          Icon(Icons.trending_up, size: 13, color: xpColor.withAlpha(200)),
          const SizedBox(width: 6),
          if (gs.sessionXp != null) ...[
            Text('Session ', style: labelStyle),
            Text(_fmt(gs.sessionXp!), style: textStyle.copyWith(color: xpColor)),
            const SizedBox(width: 10),
          ],
          if (gs.sessionXpPerMin != null) ...[
            Text('Sess/min ', style: labelStyle),
            Text(
              _fmt(gs.sessionXpPerMin!),
              style: textStyle.copyWith(color: xpColor),
            ),
            const SizedBox(width: 10),
          ],
          if (gs.xpPerMin != null) ...[
            Text('XP/min ', style: labelStyle),
            Text(_fmt(gs.xpPerMin!), style: textStyle.copyWith(color: xpColor)),
          ],
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
