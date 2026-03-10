import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/alias_rule.dart';
import '../../providers/alias_provider.dart';

/// Settings screen for managing command aliases.
///
/// Aliases expand short keywords into longer commands before
/// they are sent to the MUD.
class AliasSettingsScreen extends ConsumerWidget {
  const AliasSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aliases = ref.watch(aliasRulesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Command Aliases'),
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
      body: aliases.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.short_text,
                    size: 64,
                    color: theme.colorScheme.primary.withAlpha(80),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No aliases configured',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a command alias',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: aliases.length,
              itemBuilder: (context, index) {
                final alias = aliases[index];
                return _AliasTile(
                  alias: alias,
                  onToggle: () {
                    ref.read(aliasRulesProvider.notifier).toggleRule(alias.id);
                  },
                  onEdit: () => _showEditDialog(context, ref, alias),
                  onDelete: () {
                    ref.read(aliasRulesProvider.notifier).removeRule(alias.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted "${alias.keyword}"')),
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
        title: const Text('About Aliases'),
        content: const SingleChildScrollView(
          child: Text(
            'Aliases expand short keywords into full commands '
            'before sending to the MUD.\n\n'
            'Variable substitution:\n'
            '• \$0 — Everything after the keyword\n'
            '• \$1, \$2, ... — Individual arguments\n\n'
            'Examples:\n'
            '• "k" → "kill \$1"\n'
            '  Typing "k goblin" sends "kill goblin"\n\n'
            '• "c" → "cast \$0"\n'
            '  Typing "c fireball at goblin" sends\n'
            '  "cast fireball at goblin"\n\n'
            '• "ga" → "get all"\n'
            '  Typing "ga" sends "get all"',
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

  void _showEditDialog(BuildContext context, WidgetRef ref, AliasRule? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AliasEditScreen(existing: existing),
      ),
    );
  }
}

/// List tile for a single alias rule.
class _AliasTile extends StatelessWidget {
  final AliasRule alias;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AliasTile({
    required this.alias,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        Icons.short_text,
        color: alias.enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withAlpha(60),
      ),
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: alias.keyword,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.bold,
                color: alias.enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
            TextSpan(
              text: '  →  ',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withAlpha(80),
              ),
            ),
            TextSpan(
              text: alias.expansion,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                color: alias.enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
      ),
      subtitle: alias.description != null
          ? Text(
              alias.description!,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withAlpha(80),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: alias.enabled,
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
}

/// Edit/create screen for a single alias rule.
class _AliasEditScreen extends ConsumerStatefulWidget {
  final AliasRule? existing;

  const _AliasEditScreen({this.existing});

  @override
  ConsumerState<_AliasEditScreen> createState() => _AliasEditScreenState();
}

class _AliasEditScreenState extends ConsumerState<_AliasEditScreen> {
  late final TextEditingController _keywordController;
  late final TextEditingController _expansionController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _testInputController;
  String? _previewOutput;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _keywordController = TextEditingController(text: e?.keyword ?? '');
    _expansionController = TextEditingController(text: e?.expansion ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _testInputController = TextEditingController();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _expansionController.dispose();
    _descriptionController.dispose();
    _testInputController.dispose();
    super.dispose();
  }

  void _testExpansion() {
    final keyword = _keywordController.text.trim();
    final expansion = _expansionController.text.trim();
    final testInput = _testInputController.text.trim();

    if (keyword.isEmpty || expansion.isEmpty || testInput.isEmpty) {
      setState(() => _previewOutput = null);
      return;
    }

    final testAlias = AliasRule(
      id: 'test',
      keyword: keyword,
      expansion: expansion,
    );

    final result = testAlias.tryExpand(testInput);
    setState(() {
      _previewOutput = result ?? '(no match — input must start with "$keyword")';
    });
  }

  void _save() {
    final keyword = _keywordController.text.trim();
    final expansion = _expansionController.text.trim();

    if (keyword.isEmpty || expansion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keyword and expansion are required')),
      );
      return;
    }

    // Validate: keyword must not contain spaces.
    if (keyword.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keyword must be a single word')),
      );
      return;
    }

    final rule = AliasRule(
      id: widget.existing?.id ??
          'alias_${DateTime.now().millisecondsSinceEpoch}',
      keyword: keyword,
      expansion: expansion,
      enabled: widget.existing?.enabled ?? true,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    final notifier = ref.read(aliasRulesProvider.notifier);
    if (widget.existing != null) {
      notifier.updateRule(rule);
    } else {
      notifier.addRule(rule);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Alias' : 'New Alias'),
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
          // Keyword field.
          TextField(
            controller: _keywordController,
            decoration: const InputDecoration(
              labelText: 'Keyword',
              hintText: 'e.g., k, ga, c',
              helperText: 'The short word you type (no spaces)',
            ),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Expansion field.
          TextField(
            controller: _expansionController,
            decoration: const InputDecoration(
              labelText: 'Expands to',
              hintText: r'e.g., kill $1',
              helperText: r'Use $0 for all args, $1 $2 for individual args',
              helperMaxLines: 2,
            ),
            style: const TextStyle(fontFamily: 'JetBrainsMono'),
          ),
          const SizedBox(height: 16),

          // Description field.
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'e.g., Kill a target',
            ),
          ),
          const SizedBox(height: 24),

          // Test area.
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Test Your Alias',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testInputController,
                  decoration: const InputDecoration(
                    labelText: 'Test input',
                    hintText: 'e.g., k goblin',
                    isDense: true,
                  ),
                  style: const TextStyle(fontFamily: 'JetBrainsMono'),
                  onChanged: (_) => _testExpansion(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: _testExpansion,
                tooltip: 'Test expansion',
              ),
            ],
          ),
          if (_previewOutput != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '> $_previewOutput',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  color: Color(0xFF55FF55),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
