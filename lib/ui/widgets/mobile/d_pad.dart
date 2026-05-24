import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/alias_rule.dart';
import '../../../providers/alias_provider.dart';
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
    final pinnedIds = ref.watch(
        settingsProvider.select((s) => s.pinnedAliasIds));
    final allAliases = ref.watch(aliasRulesProvider);
    final pinnedAliases = _resolvePinnedAliases(pinnedIds, allAliases);

    void send(String command) {
      ref.read(connectionServiceProvider).sendCommand(command);
      ref.read(gameStateProvider.notifier).recordDirectionalAttempt(command);
    }

    void runAliasSlot(AliasRule rule) {
      final engine = ref.read(aliasEngineProvider);
      final service = ref.read(connectionServiceProvider);
      FocusManager.instance.primaryFocus?.unfocus();
      for (final outgoing in engine.expand(rule.keyword)) {
        if (outgoing.isNotEmpty) service.sendCommand(outgoing);
      }
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

          if (pinnedAliases.isNotEmpty) ...[
            const SizedBox(width: 8),

            // Pinned-alias column. Each button is labelled with the alias's
            // description (falling back to the keyword if none is set) and
            // dispatches via the alias engine so any `$0`/`$1` substitutions
            // are honoured (args expand to empty when fired from a quick
            // slot — pin parameterless aliases for best UX).
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < pinnedAliases.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _DPadButton(
                    label: (pinnedAliases[i].description?.trim().isNotEmpty ??
                            false)
                        ? pinnedAliases[i].description!.trim()
                        : pinnedAliases[i].keyword,
                    width: 84,
                    onPressed: () => runAliasSlot(pinnedAliases[i]),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Maps the persisted pinned-id list to the live, enabled [AliasRule]s.
  /// Stale ids (deleted aliases) and disabled aliases are skipped so the
  /// column never renders dead buttons, but the persisted list is left
  /// untouched — re-enabling an alias brings its slot back.
  List<AliasRule> _resolvePinnedAliases(
    List<String> pinnedIds,
    List<AliasRule> allAliases,
  ) {
    if (pinnedIds.isEmpty) return const [];
    final byId = {for (final a in allAliases) a.id: a};
    final result = <AliasRule>[];
    for (final id in pinnedIds) {
      final rule = byId[id];
      if (rule != null && rule.enabled) result.add(rule);
    }
    return result;
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
  final double? width;

  const _DPadButton({
    required this.label,
    this.icon,
    this.emoji,
    this.child,
    required this.onPressed,
    this.compact = false,
    this.width,
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
      // Widen the box and ellipsise so longer captions (e.g. pinned-alias
      // descriptions like "Get all from corpse") stay readable instead of
      // bursting the button.
      final wide = (width ?? 0) > 50;
      rendered = Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: wide ? 9 : (compact ? 10 : 11),
          fontWeight: FontWeight.bold,
          color: buttonColor,
          height: 1.05,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Tooltip(
        message: label,
        child: SizedBox(
          width: width ?? (compact ? 40 : 44),
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
