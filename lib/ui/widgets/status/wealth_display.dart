import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/game_state_provider.dart';

/// Displays coins on hand and bank balance side by side.
class WealthDisplay extends ConsumerWidget {
  const WealthDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
    if (gs.banks == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    const goldColor = Color(0xFFD4A057);
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
          Icon(Icons.account_balance, size: 13,
              color: goldColor.withAlpha(200)),
          const SizedBox(width: 4),
          Text('Banks ', style: labelStyle),
          Text(
            _fmt(gs.banks!),
            style: textStyle.copyWith(color: goldColor),
          ),
          if (gs.coins != null) ...[
            const SizedBox(width: 12),
            Icon(Icons.monetization_on, size: 12,
                color: goldColor.withAlpha(180)),
            const SizedBox(width: 3),
            Text('On hand ', style: labelStyle),
            Text(
              _fmt(gs.coins!),
              style: textStyle.copyWith(color: goldColor),
            ),
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
