import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/game_state_provider.dart';

/// Compact character identity card: level, race, class, age.
class CharacterCardPanel extends ConsumerWidget {
  const CharacterCardPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
    if (gs.level == null && gs.race == null) return const SizedBox.shrink();

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
          Icon(Icons.person, size: 13,
              color: theme.colorScheme.primary.withAlpha(180)),
          const SizedBox(width: 6),
          if (gs.level != null) ...[
            Text('Lv ', style: labelStyle),
            Text(
              '${gs.level}',
              style: textStyle.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (gs.race != null) ...[
            Text('Race ', style: labelStyle),
            Text(gs.race!, style: textStyle),
            const SizedBox(width: 10),
          ],
          if (gs.playerClass != null) ...[
            Text('Class ', style: labelStyle),
            Text(gs.playerClass!, style: textStyle),
            const SizedBox(width: 10),
          ],
          if (gs.age != null) ...[
            Text('Age ', style: labelStyle),
            Text('${gs.age}', style: textStyle),
          ],
        ],
      ),
    );
  }
}
