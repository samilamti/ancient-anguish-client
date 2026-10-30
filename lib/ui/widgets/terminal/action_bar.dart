import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/alias_rule.dart';
import '../../../models/game_state.dart';
import '../../../providers/alias_provider.dart';
import '../../../providers/connection_provider.dart' show connectionServiceProvider;
import '../../../providers/settings_provider.dart';
import '../../../providers/target_provider.dart';
import '../../screens/alias_settings_screen.dart' show openAliasEditor;

/// The alias a slot points at, or `null` for an empty slot or one whose
/// alias was deleted or switched off.
AliasRule? actionBarAlias(WidgetRef ref, int slot) {
  final ids = ref.read(settingsProvider).actionBarAliasIds;
  if (slot < 0 || slot >= ids.length || ids[slot] == null) return null;
  for (final rule in ref.read(aliasRulesProvider)) {
    if (rule.id == ids[slot]) return rule.enabled ? rule : null;
  }
  return null;
}

/// The command typed in play mode that was auto-added to [slot], or null.
/// A slot the player gave an alias never shows one.
String? actionBarCommand(WidgetRef ref, int slot) {
  final settings = ref.read(settingsProvider);
  if (slot < 0 || slot >= AppSettings.actionBarSlots) return null;
  if (settings.actionBarAliasIds[slot] != null) return null;
  return settings.actionBarCommands[slot];
}

/// What pressing [slot] would run: the alias keyword or the saved command.
String? _slotLine(WidgetRef ref, int slot) =>
    actionBarAlias(ref, slot)?.keyword ?? actionBarCommand(ref, slot);

/// Fires action-bar [slot] (0-based): its alias or saved command, expanded
/// exactly as if it had been typed. One press, one dispatch; a `$target` line
/// with no target is refused by the alias engine, which says "No target.".
/// Returns the commands sent, for the play-mode key overlay.
List<String> runActionBarSlot(WidgetRef ref, int slot) {
  final line = _slotLine(ref, slot);
  if (line == null) return const [];
  final service = ref.read(connectionServiceProvider);
  final sent = [
    for (final outgoing in ref.read(aliasEngineProvider).expand(line))
      if (outgoing.isNotEmpty) outgoing,
  ];
  sent.forEach(service.sendCommand);
  return sent;
}

/// Called with each line typed and sent in play mode: puts it on the bar's
/// first free slot. Movement (it has its own keys) and client `#` commands
/// are left off, as is anything already on the bar, by command or by alias
/// keyword. Once all ten slots are taken nothing more is added.
void autoAddTypedCommand(WidgetRef ref, String command) {
  final cmd = command.trim();
  if (cmd.isEmpty || cmd.startsWith('#')) return;
  if (GameState.directionalCommands.contains(cmd.toLowerCase())) return;
  final onBar = {
    for (var i = 0; i < AppSettings.actionBarSlots; i++)
      ?actionBarAlias(ref, i)?.keyword,
  };
  ref
      .read(settingsProvider.notifier)
      .autoAddActionBarCommand(cmd, onBar: onBar);
}

/// Opens the alias picker for [slot] and stores the choice.
Future<void> assignActionBarSlot(
    BuildContext context, WidgetRef ref, int slot) async {
  final aliases = ref.read(aliasRulesProvider);
  final current = ref.read(settingsProvider).actionBarAliasIds[slot];
  final hasCommand = actionBarCommand(ref, slot) != null;
  final choice = await showDialog<_SlotChoice>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('Slot ${_keyLabel(slot)}'),
      children: [
        for (final rule in aliases)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _SlotChoice.alias(rule.id)),
            child: Row(
              children: [
                Icon(
                  rule.id == current ? Icons.check : null,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(rule.keyword,
                    style: const TextStyle(fontFamily: 'JetBrainsMono')),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rule.expansion,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Divider(),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const _SlotChoice.create()),
          child: const Text('New alias…'),
        ),
        if (current != null || hasCommand)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, const _SlotChoice.clear()),
            child: const Text('Clear slot'),
          ),
      ],
    ),
  );
  if (choice == null) return;
  final settings = ref.read(settingsProvider.notifier);
  if (choice.create) {
    if (!context.mounted) return;
    final before = {for (final r in ref.read(aliasRulesProvider)) r.id};
    await openAliasEditor(context);
    final added = ref
        .read(aliasRulesProvider)
        .where((r) => !before.contains(r.id))
        .toList();
    if (added.isNotEmpty) settings.setActionBarSlot(slot, added.last.id);
    return;
  }
  settings.setActionBarSlot(slot, choice.aliasId);
}

class _SlotChoice {
  final String? aliasId;
  final bool create;
  const _SlotChoice.alias(String this.aliasId) : create = false;
  const _SlotChoice.create()
      : aliasId = null,
        create = true;
  const _SlotChoice.clear()
      : aliasId = null,
        create = false;
}

String _keyLabel(int slot) => slot == 9 ? '0' : '${slot + 1}';

/// The 10-slot row shown above the input strip in play mode. Click a slot to
/// fire it; right-click or long-press to assign an alias.
class ActionBar extends ConsumerWidget {
  /// Shown at the left of the bar (the target chip).
  final Widget? leading;

  const ActionBar({super.key, this.leading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched so the bar redraws on assignment, alias edits and targeting.
    ref.watch(settingsProvider.select((s) => s.actionBarAliasIds));
    ref.watch(settingsProvider.select((s) => s.actionBarCommands));
    ref.watch(aliasRulesProvider);
    final hasTarget = ref.watch(targetProvider) != null;
    final engine = ref.read(aliasEngineProvider);
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          ?leading,
          for (var i = 0; i < AppSettings.actionBarSlots; i++)
            Expanded(
              child: Builder(builder: (context) {
                final rule = actionBarAlias(ref, i);
                final command = actionBarCommand(ref, i);
                final line = rule?.keyword ?? command;
                final needsTarget = line != null && engine.usesTarget(line);
                return _Slot(
                  keyLabel: _keyLabel(i),
                  label: line,
                  tooltip: rule?.expansion ?? command,
                  auto: rule == null && command != null,
                  dimmed: needsTarget && !hasTarget,
                  onTap: () => runActionBarSlot(ref, i),
                  onAssign: () => assignActionBarSlot(context, ref, i),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  final String keyLabel;
  final String? label;
  final String? tooltip;
  final bool dimmed;

  /// Filled from a typed command rather than assigned: shown in italics.
  final bool auto;
  final VoidCallback onTap;
  final VoidCallback onAssign;

  const _Slot({
    required this.keyLabel,
    required this.label,
    required this.tooltip,
    required this.dimmed,
    this.auto = false,
    required this.onTap,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final slot = GestureDetector(
      onSecondaryTap: onAssign,
      onLongPress: onAssign,
      child: InkWell(
        // An empty slot assigns on click too, which is what its + says.
        onTap: label == null ? onAssign : onTap,
        child: Opacity(
          opacity: dimmed ? 0.4 : 1,
          child: Container(
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              border: Border.all(color: primary.withAlpha(90)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Text(
                  keyLabel,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    color: primary.withAlpha(150),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label ?? '+',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: label == null ? TextAlign.center : null,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      color: label == null ? primary.withAlpha(120) : primary,
                      fontStyle: auto ? FontStyle.italic : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return slot;
    // Manual trigger: a long-press is the assign gesture here.
    return Tooltip(
      message: tooltip!,
      triggerMode: TooltipTriggerMode.manual,
      child: slot,
    );
  }
}
