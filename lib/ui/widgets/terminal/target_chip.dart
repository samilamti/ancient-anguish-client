import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/terminal_colors.dart';
import '../../../providers/connection_provider.dart' show terminalBufferProvider;
import '../../../providers/room_targets_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/target_provider.dart';

/// The red `🎯 orc` chip naming what `$target` expands to. Tapping it moves
/// to the next target, like Tab.
///
/// [hideWhenEmpty] is for the phone, where the chip sits above the D-pad
/// only while something is targeted. On the desktop action bar it stays, as
/// a faint placeholder, so the bar doesn't shift when a target appears.
class TargetChip extends ConsumerWidget {
  final bool hideWhenEmpty;

  const TargetChip({super.key, this.hideWhenEmpty = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(targetProvider);
    if (target == null && hideWhenEmpty) return const SizedBox.shrink();

    // "Tab" hints that there is something else to cycle to. Watched so the
    // hint follows the room, new kill links and the ignore list.
    ref.watch(settingsProvider.select((s) => s.ignoredKillTargets));
    ref.watch(roomTargetInstancesProvider);
    ref.watch(terminalBufferProvider);
    final candidates = ref.read(targetProvider.notifier).candidates.length;
    final red = TerminalColors.brightRed;
    final style = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 13,
      color: target == null ? red.withAlpha(110) : red,
      fontWeight: target == null ? FontWeight.normal : FontWeight.bold,
    );

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => ref.read(targetProvider.notifier).next(),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: red.withAlpha(target == null ? 10 : 30),
            border: Border.all(color: red.withAlpha(target == null ? 60 : 160)),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎯 ${target ?? 'no target'}', style: style),
              if (target != null && candidates > 1) ...[
                const SizedBox(width: 6),
                Text(
                  'Tab',
                  style: style.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                    color: red.withAlpha(110),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
