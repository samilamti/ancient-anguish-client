import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/game_state_provider.dart';

/// Displays game time and reboot countdown.
class WorldClockPanel extends ConsumerWidget {
  const WorldClockPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
    if (!gs.hasWorldInfo) return const SizedBox.shrink();

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
          if (gs.gametime != null) ...[
            Icon(Icons.access_time, size: 13,
                color: theme.colorScheme.onSurface.withAlpha(140)),
            const SizedBox(width: 4),
            Text('Oerthe ', style: labelStyle),
            Text(gs.gametime!, style: textStyle),
          ],
          if (gs.gametime != null && gs.reboot != null)
            const SizedBox(width: 14),
          if (gs.reboot != null) ...[
            Icon(Icons.hourglass_bottom, size: 13,
                color: const Color(0xFFCC8800).withAlpha(200)),
            const SizedBox(width: 4),
            Text('Reboot ', style: labelStyle),
            Text(
              gs.reboot!,
              style: textStyle.copyWith(color: const Color(0xFFCC8800)),
            ),
          ],
        ],
      ),
    );
  }
}
