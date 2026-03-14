import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/trigger_rule.dart';
import '../../providers/trigger_provider.dart';

/// Settings screen for managing trigger/highlight rules.
///
/// Allows users to create, edit, delete, and toggle trigger rules
/// that highlight text or play sounds on pattern matches.
class TriggerSettingsScreen extends ConsumerWidget {
  const TriggerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggers = ref.watch(triggerRulesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Immersions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Help',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: triggers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.highlight,
                    size: 64,
                    color: theme.colorScheme.primary.withAlpha(80),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No immersions configured',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add an immersion rule',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: triggers.length,
              itemBuilder: (context, index) {
                final trigger = triggers[index];
                return _TriggerTile(
                  trigger: trigger,
                  onToggle: () {
                    ref.read(triggerRulesProvider.notifier).toggleRule(trigger.id);
                  },
                  onEdit: () => _showEditDialog(context, ref, trigger),
                  onDelete: () {
                    ref.read(triggerRulesProvider.notifier).removeRule(trigger.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted "${trigger.name}"')),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Immersions'),
        content: const SingleChildScrollView(
          child: Text(
            'Immersions match patterns in MUD output and perform '
            'client-side actions:\n\n'
            '• Highlight — Change the color/style of matched text.\n'
            '• Play Sound — Play an MP3 when the pattern is seen.\n'
            '• Gag — Hide matching lines from the terminal.\n\n'
            'Patterns use regular expressions (regex).\n'
            'Example: "\\w+ tells you:" matches any tell.\n\n'
            'Note: Ancient Anguish prohibits immersions that auto-send '
            'commands. These immersions only perform visual/audio actions.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, TriggerRule? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TriggerEditScreen(existing: existing),
      ),
    );
  }
}

/// A list tile for a single trigger rule.
class _TriggerTile extends StatelessWidget {
  final TriggerRule trigger;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TriggerTile({
    required this.trigger,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: _actionIcon(trigger.action, theme),
      title: Text(
        trigger.name,
        style: TextStyle(
          color: trigger.enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withAlpha(100),
        ),
      ),
      subtitle: Text(
        '/${trigger.pattern}/',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 11,
          color: theme.colorScheme.onSurface.withAlpha(80),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trigger.highlightForeground != null)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: trigger.highlightForeground,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withAlpha(40),
                ),
              ),
            ),
          Switch(
            value: trigger.enabled,
            onChanged: (_) => onToggle(),
          ),
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
    );
  }

  Widget _actionIcon(TriggerAction action, ThemeData theme) {
    return switch (action) {
      TriggerAction.highlight => Icon(
          Icons.format_paint,
          color: theme.colorScheme.primary,
        ),
      TriggerAction.playSound => Icon(
          Icons.volume_up,
          color: theme.colorScheme.primary,
        ),
      TriggerAction.highlightAndSound => Icon(
          Icons.auto_awesome,
          color: theme.colorScheme.primary,
        ),
      TriggerAction.gag => Icon(
          Icons.visibility_off,
          color: theme.colorScheme.error,
        ),
    };
  }
}

/// Edit/create screen for a single trigger rule.
class _TriggerEditScreen extends ConsumerStatefulWidget {
  final TriggerRule? existing;

  const _TriggerEditScreen({this.existing});

  @override
  ConsumerState<_TriggerEditScreen> createState() => _TriggerEditScreenState();
}

class _TriggerEditScreenState extends ConsumerState<_TriggerEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _patternController;
  late TriggerAction _action;
  late Color _fgColor;
  late Color? _bgColor;
  late bool _bold;
  late bool _wholeLine;
  String? _soundPath;
  String? _patternError;

  // Predefined color palette for the picker.
  static const List<Color> _colorOptions = [
    Color(0xFFFF0000), // Red
    Color(0xFFFF6600), // Orange
    Color(0xFFFFFF00), // Yellow
    Color(0xFF00FF00), // Green
    Color(0xFF00FFFF), // Cyan
    Color(0xFF0088FF), // Blue
    Color(0xFFFF00FF), // Magenta
    Color(0xFFFFFFFF), // White
    Color(0xFFFF5555), // Bright red
    Color(0xFF55FF55), // Bright green
    Color(0xFF5555FF), // Bright blue
    Color(0xFFFFAA00), // Gold
  ];

  static const List<Color> _bgColorOptions = [
    Color(0x00000000), // Transparent (none)
    Color(0xFFCC0000), // Dark red
    Color(0xFF006600), // Dark green
    Color(0xFF000066), // Dark blue
    Color(0xFF333300), // Dark yellow
    Color(0xFF660066), // Dark magenta
    Color(0xFF333333), // Dark grey
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _patternController = TextEditingController(text: e?.pattern ?? '');
    _action = e?.action ?? TriggerAction.highlight;
    _fgColor = e?.highlightForeground ?? const Color(0xFF00FF00);
    _bgColor = e?.highlightBackground;
    _bold = e?.highlightBold ?? false;
    _wholeLine = e?.highlightWholeLine ?? false;
    _soundPath = e?.soundPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    super.dispose();
  }

  void _validatePattern(String pattern) {
    try {
      RegExp(pattern);
      setState(() => _patternError = null);
    } catch (e) {
      debugPrint('TriggerEditScreen._validatePattern error: $e');
      setState(() => _patternError = 'Invalid regex: $e');
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    final pattern = _patternController.text.trim();

    if (name.isEmpty || pattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and pattern are required')),
      );
      return;
    }

    if (_patternError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fix the regex pattern first')),
      );
      return;
    }

    final rule = TriggerRule(
      id: widget.existing?.id ??
          'trig_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      pattern: pattern,
      enabled: widget.existing?.enabled ?? true,
      action: _action,
      highlightForeground: _fgColor,
      highlightBackground: _bgColor,
      highlightBold: _bold,
      highlightWholeLine: _wholeLine,
      soundPath: _soundPath,
    );

    final notifier = ref.read(triggerRulesProvider.notifier);
    if (widget.existing != null) {
      notifier.updateRule(rule);
    } else {
      notifier.addRule(rule);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final showHighlightOptions =
        _action == TriggerAction.highlight ||
        _action == TriggerAction.highlightAndSound;
    final showSoundOptions =
        _action == TriggerAction.playSound ||
        _action == TriggerAction.highlightAndSound;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Immersion' : 'New Immersion'),
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
          // Name field.
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Immersion Name',
              hintText: 'e.g., Tells, Combat hits',
            ),
          ),
          const SizedBox(height: 16),

          // Pattern field.
          TextField(
            controller: _patternController,
            decoration: InputDecoration(
              labelText: 'Pattern (regex)',
              hintText: r'e.g., \w+ tells you:',
              errorText: _patternError,
              helperText: 'Regular expression matched against each line',
              helperMaxLines: 2,
            ),
            onChanged: _validatePattern,
            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Action type selector.
          Text(
            'Action',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<TriggerAction>(
            segments: const [
              ButtonSegment(
                value: TriggerAction.highlight,
                label: Text('Color'),
                icon: Icon(Icons.format_paint),
              ),
              ButtonSegment(
                value: TriggerAction.playSound,
                label: Text('Sound'),
                icon: Icon(Icons.volume_up),
              ),
              ButtonSegment(
                value: TriggerAction.highlightAndSound,
                label: Text('Both'),
                icon: Icon(Icons.auto_awesome),
              ),
              ButtonSegment(
                value: TriggerAction.gag,
                label: Text('Gag'),
                icon: Icon(Icons.visibility_off),
              ),
            ],
            selected: {_action},
            onSelectionChanged: (selected) {
              setState(() => _action = selected.first);
            },
          ),
          const SizedBox(height: 24),

          // Highlight options.
          if (showHighlightOptions) ...[
            Text(
              'Highlight Color',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _colorOptions.map((color) {
                final isSelected = color.toARGB32() == _fgColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _fgColor = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 18, color: Colors.black)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Text(
              'Background Color',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _bgColorOptions.map((color) {
                final isNone = (color.a * 255.0).round().clamp(0, 255) == 0;
                final isSelected = isNone
                    ? _bgColor == null
                    : color.toARGB32() == _bgColor?.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() {
                    _bgColor = isNone ? null : color;
                  }),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isNone ? Colors.transparent : color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.grey.withAlpha(60),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: isNone
                        ? const Icon(Icons.block, size: 18, color: Colors.grey)
                        : isSelected
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Bold text'),
              value: _bold,
              onChanged: (v) => setState(() => _bold = v),
            ),
            SwitchListTile(
              title: const Text('Highlight entire line'),
              subtitle: const Text('Apply color to the full line, not just the match'),
              value: _wholeLine,
              onChanged: (v) => setState(() => _wholeLine = v),
            ),
            const SizedBox(height: 8),

            // Preview.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _wholeLine
                          ? 'Gandalf tells you: Hello adventurer!'
                          : 'Gandalf tells you: ',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        color: _wholeLine ? _fgColor : _fgColor,
                        backgroundColor: _bgColor,
                        fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (!_wholeLine)
                      const TextSpan(
                        text: 'Hello adventurer!',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 13,
                          color: Color(0xFFCCCCCC),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // Sound options.
          if (showSoundOptions) ...[
            const SizedBox(height: 16),
            Text(
              'Sound File',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _soundPath != null
                        ? _soundPath!.split('/').last.split('\\').last
                        : 'No file selected',
                    style: TextStyle(
                      color: _soundPath != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withAlpha(100),
                      fontStyle: _soundPath != null
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_soundPath != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _soundPath = null),
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Browse...'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['mp3'],
                    );
                    if (result != null && result.files.single.path != null) {
                      setState(() => _soundPath = result.files.single.path);
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
