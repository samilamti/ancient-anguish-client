import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/text_link_rule.dart';
import '../../providers/settings_provider.dart';
import '../../providers/text_link_rule_provider.dart';
import '../widgets/common/escape_dismiss.dart';

/// Settings screen for managing text-to-link rules. Each rule promotes
/// matching MUD output to a tappable command link so the user can act on
/// it without typing.
class TextLinkRulesScreen extends ConsumerWidget {
  const TextLinkRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(textLinkRulesProvider);
    final theme = Theme.of(context);

    return EscapeDismiss(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Text Link Rules'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog(context),
              tooltip: 'Help',
            ),
            IconButton(
              icon: const Icon(Icons.restore),
              onPressed: () => _confirmResetDefaults(context, ref),
              tooltip: 'Reset to defaults',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openEditor(context, null),
          child: const Icon(Icons.add),
        ),
        body: rules.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link,
                      size: 64,
                      color: theme.colorScheme.primary.withAlpha(80),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No text link rules',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add a rule, or restore the bundled defaults.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  const _ShortcutHintBanner(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: rules.length,
                      itemBuilder: (context, index) {
                        final rule = rules[index];
                        return _RuleTile(
                          rule: rule,
                          onToggle: () => ref
                              .read(textLinkRulesProvider.notifier)
                              .toggleRule(rule.id),
                          onEdit: () => _openEditor(context, rule),
                          onDelete: () {
                            ref
                                .read(textLinkRulesProvider.notifier)
                                .removeRule(rule.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Deleted "${rule.name}"')),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openEditor(BuildContext context, TextLinkRule? existing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TextLinkRuleEditScreen(existing: existing),
      ),
    );
  }

  void _confirmResetDefaults(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to defaults?'),
        content: const Text(
          'This replaces the current rule list with the bundled defaults. '
          'Custom rules you added will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(textLinkRulesProvider.notifier).resetToDefaults();
              Navigator.pop(ctx);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('About Text Link Rules'),
        content: const SingleChildScrollView(
          child: Text(
            'Text link rules turn MUD output into tappable shortcuts. '
            'When a line matches the rule\'s regex pattern, the matched '
            'text becomes a link; tapping it sends the command template '
            'to the MUD.\n\n'
            'Pattern syntax:\n'
            '• Standard Dart RegExp — \\w+, [a-z], (group), etc.\n'
            '• Capture groups become \$1, \$2, … in the template.\n\n'
            'Examples:\n'
            '• Pattern: You must be standing\\.\n'
            '  Command: stand\n\n'
            '• Pattern: The (\\w+) door is closed\\.\n'
            '  Command: open \$1 door\n'
            '  → "The dark door is closed." sends "open dark door"',
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
}

/// One-line tip above the rules list reminding users that the keyboard
/// shortcut exists. Material-styled so it inherits the theme without any
/// extra config; shown only when the list is non-empty (the empty state
/// already steals the screen).
class _ShortcutHintBanner extends StatelessWidget {
  const _ShortcutHintBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = (theme.platform == TargetPlatform.macOS ||
            theme.platform == TargetPlatform.iOS)
        ? '⌘L'
        : 'Ctrl+L';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.primary.withAlpha(20),
      child: Row(
        children: [
          Icon(
            Icons.keyboard,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Press $hint to fire the most recently rendered link.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(200),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final TextLinkRule rule;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleTile({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compiles = rule.regex != null;

    return ListTile(
      leading: Icon(
        compiles ? Icons.link : Icons.error_outline,
        color: !rule.enabled
            ? theme.colorScheme.onSurface.withAlpha(60)
            : compiles
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
      ),
      title: Text(
        rule.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: rule.enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withAlpha(100),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '/${rule.pattern}/',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '→ ${rule.commandTemplate}',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!compiles)
            Text(
              'Invalid regex — rule is skipped',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: rule.enabled,
            onChanged: (_) => onToggle(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
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

class _TextLinkRuleEditScreen extends ConsumerStatefulWidget {
  final TextLinkRule? existing;

  const _TextLinkRuleEditScreen({this.existing});

  @override
  ConsumerState<_TextLinkRuleEditScreen> createState() =>
      _TextLinkRuleEditScreenState();
}

class _TextLinkRuleEditScreenState
    extends ConsumerState<_TextLinkRuleEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _patternController;
  late final TextEditingController _commandController;
  late final TextEditingController _testController;
  String? _previewError;
  String? _previewMatch;
  String? _previewCommand;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _patternController = TextEditingController(text: e?.pattern ?? '');
    _commandController =
        TextEditingController(text: e?.commandTemplate ?? '');
    _testController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    _commandController.dispose();
    _testController.dispose();
    super.dispose();
  }

  void _runPreview() {
    final patternText = _patternController.text;
    final commandText = _commandController.text;
    final input = _testController.text;
    if (patternText.isEmpty || commandText.isEmpty || input.isEmpty) {
      setState(() {
        _previewError = null;
        _previewMatch = null;
        _previewCommand = null;
      });
      return;
    }

    RegExp? regex;
    try {
      regex = RegExp(patternText);
    } catch (e) {
      setState(() {
        _previewError = 'Invalid regex: $e';
        _previewMatch = null;
        _previewCommand = null;
      });
      return;
    }

    final match = regex.firstMatch(input);
    if (match == null) {
      setState(() {
        _previewError = 'No match in test input';
        _previewMatch = null;
        _previewCommand = null;
      });
      return;
    }

    final tempRule = TextLinkRule(
      id: 'preview',
      name: 'preview',
      pattern: patternText,
      commandTemplate: commandText,
    );
    setState(() {
      _previewError = null;
      _previewMatch = match.group(0);
      _previewCommand = tempRule.resolveCommand(match);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final pattern = _patternController.text.trim();
    final command = _commandController.text.trim();

    if (name.isEmpty || pattern.isEmpty || command.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
      return;
    }

    try {
      RegExp(pattern);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid regex: $e')),
      );
      return;
    }

    final rule = TextLinkRule(
      id: widget.existing?.id ??
          'tlr_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      pattern: pattern,
      commandTemplate: command,
      enabled: widget.existing?.enabled ?? true,
    );

    final notifier = ref.read(textLinkRulesProvider.notifier);
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
    final mib = ref.watch(settingsProvider.select((s) => s.mobileInput));

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Text Link Rule' : 'New Text Link Rule'),
        actions: [
          TextButton(onPressed: _save, child: const Text('SAVE')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            autocorrect: mib.autocorrect,
            enableSuggestions: mib.enableSuggestions,
            smartDashesType: mib.smartDashesType,
            smartQuotesType: mib.smartQuotesType,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g., Open closed door',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _patternController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Pattern (regex)',
              hintText: r'e.g., The (\w+) door is closed\.',
              helperText: 'Standard Dart regex; capture groups → \$1, \$2, …',
              helperMaxLines: 2,
            ),
            style: const TextStyle(fontFamily: 'JetBrainsMono'),
            onChanged: (_) => _runPreview(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commandController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Command template',
              hintText: r'e.g., open $1 door',
              helperText: r'Use $1, $2, … for captures; $0 = whole match',
              helperMaxLines: 2,
            ),
            style: const TextStyle(fontFamily: 'JetBrainsMono'),
            onChanged: (_) => _runPreview(),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Test the rule',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _testController,
            autocorrect: mib.autocorrect,
            enableSuggestions: mib.enableSuggestions,
            smartDashesType: mib.smartDashesType,
            smartQuotesType: mib.smartQuotesType,
            decoration: const InputDecoration(
              labelText: 'Test input',
              hintText: 'Paste a MUD output line',
            ),
            style: const TextStyle(fontFamily: 'JetBrainsMono'),
            onChanged: (_) => _runPreview(),
          ),
          if (_previewError != null) ...[
            const SizedBox(height: 8),
            Text(
              _previewError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
          ] else if (_previewMatch != null && _previewCommand != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Match: $_previewMatch',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      color: Color(0xFFFFCC55),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '→ $_previewCommand',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      color: Color(0xFF55FF55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
