import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connection_provider.dart';
import '../../../providers/game_state_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/quick_command_icons.dart';
import 'quick_command_runner.dart';

/// A compass-rose directional pad for mobile navigation, with floor-change
/// buttons and the user's enabled quick commands stacked vertically beside it.
///
/// Compass + Up/Down handle movement and the room re-render (center "look"),
/// while the third column hosts whatever `QuickCommand`s the user has
/// enabled (Kill, Loot, Inventory by default).
class DPad extends ConsumerWidget {
  const DPad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final commands = ref.watch(settingsProvider
        .select((s) => s.quickCommands.where((c) => c.enabled).toList()));

    void send(String command) {
      ref.read(connectionServiceProvider).sendCommand(command);
      ref.read(gameStateProvider.notifier).recordDirectionalAttempt(command);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(200),
        border: Border(
          top: BorderSide(color: theme.colorScheme.primary.withAlpha(40)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Compass rose (intrinsic width — no longer Expanded).
          _CompassRose(onDirection: send),

          const SizedBox(width: 8),

          // Floor navigation column.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DPadButton(
                label: 'Up',
                emoji: '🔼',
                onPressed: () => send('up'),
              ),
              const SizedBox(height: 4),
              _DPadButton(
                label: 'Down',
                emoji: '🔽',
                onPressed: () => send('down'),
              ),
            ],
          ),

          if (commands.isNotEmpty) ...[
            const SizedBox(width: 8),

            // Quick-command column (Kill, Loot, Inventory, …).
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < commands.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _DPadButton(
                    label: commands[i].label,
                    child: iconWidgetFromName(
                      commands[i].iconName,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () =>
                        runQuickCommand(context, ref, commands[i]),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The 8-direction compass rose widget. The center cell doubles as a Look
/// button so the user can re-render the current room without leaving the
/// D-Pad.
class _CompassRose extends StatelessWidget {
  final void Function(String command) onDirection;

  const _CompassRose({required this.onDirection});

  @override
  Widget build(BuildContext context) {
    // 3x3 grid layout for the compass.
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        TableRow(children: [
          _DPadButton(
            label: 'NW',
            emoji: '↖️',
            onPressed: () => onDirection('northwest'),
            compact: true,
          ),
          _DPadButton(
            label: 'N',
            emoji: '↑',
            onPressed: () => onDirection('north'),
          ),
          _DPadButton(
            label: 'NE',
            emoji: '↗️',
            onPressed: () => onDirection('northeast'),
            compact: true,
          ),
        ]),
        TableRow(children: [
          _DPadButton(
            label: 'W',
            emoji: '←',
            onPressed: () => onDirection('west'),
          ),
          _DPadButton(
            label: 'Look',
            icon: Icons.visibility,
            onPressed: () => onDirection('look'),
          ),
          _DPadButton(
            label: 'E',
            emoji: '→',
            onPressed: () => onDirection('east'),
          ),
        ]),
        TableRow(children: [
          _DPadButton(
            label: 'SW',
            emoji: '↙️',
            onPressed: () => onDirection('southwest'),
            compact: true,
          ),
          _DPadButton(
            label: 'S',
            emoji: '↓',
            onPressed: () => onDirection('south'),
          ),
          _DPadButton(
            label: 'SE',
            emoji: '↘️',
            onPressed: () => onDirection('southeast'),
            compact: true,
          ),
        ]),
      ],
    );
  }
}

/// A single direction button on the D-Pad.
///
/// Exactly one of [emoji], [icon], or [child] should be provided; [label]
/// is always used for the tooltip/semantic text. [child] lets callers pass
/// an arbitrary widget (used for the quick-command column whose icons mix
/// emoji glyphs and Material icons through `iconWidgetFromName`).
class _DPadButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? emoji;
  final Widget? child;
  final VoidCallback onPressed;
  final bool compact;

  const _DPadButton({
    required this.label,
    this.icon,
    this.emoji,
    this.child,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = theme.colorScheme.primary;

    final Widget rendered;
    if (child != null) {
      rendered = child!;
    } else if (emoji != null) {
      rendered = Text(
        emoji!,
        style: TextStyle(fontSize: compact ? 18 : 22, height: 1.0),
      );
    } else if (icon != null) {
      rendered = Icon(icon, size: 22, color: buttonColor);
    } else {
      rendered = Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.bold,
          color: buttonColor,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Tooltip(
        message: label,
        child: SizedBox(
          width: compact ? 40 : 44,
          height: compact ? 36 : 44,
          child: Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: buttonColor.withAlpha(80)),
            ),
            child: InkWell(
              onTap: () {
                // Hide the soft keyboard when moving around so the room text
                // isn't occluded by it.
                FocusManager.instance.primaryFocus?.unfocus();
                onPressed();
              },
              borderRadius: BorderRadius.circular(8),
              child: Center(child: rendered),
            ),
          ),
        ),
      ),
    );
  }
}
