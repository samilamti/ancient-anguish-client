import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quick_command.dart';
import '../../providers/settings_provider.dart';
import '../../utils/quick_command_icons.dart';

/// Settings screen for managing mobile quick-command buttons.
class QuickCommandsSettingsScreen extends ConsumerWidget {
  const QuickCommandsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref.watch(settingsProvider.select((s) => s.quickCommands));
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Commands'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restore defaults',
            onPressed: () => _confirmReset(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: commands.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_view,
                    size: 64,
                    color: theme.colorScheme.primary.withAlpha(80),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No quick commands configured',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add one',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: commands.length,
              onReorder: (oldIndex, newIndex) {
                final reordered = [...commands];
                final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
                final moved = reordered.removeAt(oldIndex);
                reordered.insert(adjusted, moved);
                notifier.setQuickCommands(reordered);
              },
              itemBuilder: (context, index) {
                final cmd = commands[index];
                return _QuickCommandTile(
                  key: ValueKey(cmd.id),
                  command: cmd,
                  onToggle: () {
                    final updated = [...commands];
                    updated[index] = cmd.copyWith(enabled: !cmd.enabled);
                    notifier.setQuickCommands(updated);
                  },
                  onEdit: () => _openEditor(context, ref, cmd),
                  onDelete: () {
                    final updated = [...commands]..removeAt(index);
                    notifier.setQuickCommands(updated);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted "${cmd.label}"')),
                    );
                  },
                );
              },
            ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, QuickCommand? existing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _QuickCommandEditScreen(existing: existing),
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore defaults?'),
        content: const Text(
          'Replaces your current quick commands with Look, Kill, Loot, Inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(settingsProvider.notifier)
                  .setQuickCommands(QuickCommand.defaults);
              Navigator.pop(dialogContext);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

class _QuickCommandTile extends StatelessWidget {
  final QuickCommand command;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuickCommandTile({
    super.key,
    required this.command,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = [
      command.command,
      if (command.selectTarget) '+ target picker',
    ];

    return ListTile(
      leading: iconWidgetFromName(
        command.iconName,
        size: 24,
        color: command.enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withAlpha(60),
      ),
      title: Text(
        command.label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: command.enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withAlpha(100),
        ),
      ),
      subtitle: Text(
        subtitleParts.join('  '),
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          color: theme.colorScheme.onSurface.withAlpha(120),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: command.enabled, onChanged: (_) => onToggle()),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

class _QuickCommandEditScreen extends ConsumerStatefulWidget {
  final QuickCommand? existing;

  const _QuickCommandEditScreen({this.existing});

  @override
  ConsumerState<_QuickCommandEditScreen> createState() =>
      _QuickCommandEditScreenState();
}

class _QuickCommandEditScreenState
    extends ConsumerState<_QuickCommandEditScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _commandController;
  late String _iconName;
  late bool _selectTarget;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelController = TextEditingController(text: e?.label ?? '');
    _commandController = TextEditingController(text: e?.command ?? '');
    _iconName = e?.iconName ?? availableIconNames().first;
    _selectTarget = e?.selectTarget ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  void _save() {
    final label = _labelController.text.trim();
    final command = _commandController.text.trim();

    if (label.isEmpty || command.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label and command are required')),
      );
      return;
    }

    final existing = widget.existing;
    final rule = QuickCommand(
      id: existing?.id ??
          'quick_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      iconName: _iconName,
      command: command,
      selectTarget: _selectTarget,
      enabled: existing?.enabled ?? true,
    );

    final current = ref.read(settingsProvider).quickCommands;
    final updated = [...current];
    if (existing != null) {
      final idx = updated.indexWhere((c) => c.id == existing.id);
      if (idx >= 0) {
        updated[idx] = rule;
      } else {
        updated.add(rule);
      }
    } else {
      updated.add(rule);
    }
    ref.read(settingsProvider.notifier).setQuickCommands(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final theme = Theme.of(context);
    final iconNames = availableIconNames();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Quick Command' : 'New Quick Command'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'e.g., Kill',
              helperText: 'Shown as the button tooltip',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commandController,
            decoration: const InputDecoration(
              labelText: 'Command',
              hintText: 'e.g., kill, get all from corpse',
            ),
            style: const TextStyle(fontFamily: 'JetBrainsMono'),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Select target from recent words'),
            subtitle: const Text(
              'Opens a picker, then sends "<command> <chosen>"',
            ),
            value: _selectTarget,
            onChanged: (value) => setState(() => _selectTarget = value),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          Text(
            'Icon',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: iconNames.length,
            itemBuilder: (context, index) {
              final name = iconNames[index];
              final selected = name == _iconName;
              return InkWell(
                onTap: () => setState(() => _iconName = name),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withAlpha(40),
                      width: selected ? 2 : 1,
                    ),
                    color: selected
                        ? theme.colorScheme.primary.withAlpha(30)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconWidgetFromName(
                        name,
                        size: 24,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 9,
                          color:
                              theme.colorScheme.onSurface.withAlpha(160),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
