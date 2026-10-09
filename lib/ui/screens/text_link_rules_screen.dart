import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/text_link_rule.dart';
import '../../providers/command_trigger_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/text_link_rule_provider.dart';
import '../widgets/common/escape_dismiss.dart';

/// Which rule list a [TextLinkRulesScreen] edits. Both share the
/// [TextLinkRule] model; text links render matches as tappable links, command
/// triggers send the command on their own once the player has gone idle.
enum RuleListKind {
  textLink,
  commandTrigger;

  NotifierProvider<TextLinkRulesNotifier, List<TextLinkRule>> get provider =>
      switch (this) {
        textLink => textLinkRulesProvider,
        commandTrigger => commandTriggerRulesProvider,
      };

  String get noun => switch (this) {
        textLink => 'Text Link Rule',
        commandTrigger => 'Command Trigger',
      };

  IconData get icon => switch (this) {
        textLink => Icons.link,
        commandTrigger => Icons.bolt,
      };

  String get idPrefix => switch (this) {
        textLink => 'tlr',
        commandTrigger => 'ctr',
      };

  /// Command triggers never need a name: an empty one becomes `Trigger N`.
  bool get nameOptional => this == commandTrigger;
}

/// Settings screen for managing text-to-link rules. Each rule promotes
/// matching MUD output to a tappable command link so the user can act on
/// it without typing. With [kind] set to [RuleListKind.commandTrigger] it
/// edits command triggers instead.
class TextLinkRulesScreen extends ConsumerWidget {
  const TextLinkRulesScreen({super.key, this.kind = RuleListKind.textLink});

  final RuleListKind kind;

  bool get _isTrigger => kind == RuleListKind.commandTrigger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(kind.provider);
    final theme = Theme.of(context);

    return EscapeDismiss(
      child: Scaffold(
        appBar: AppBar(
          title: Text('${kind.noun}s'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog(context),
              tooltip: 'Help',
            ),
            if (!_isTrigger)
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
                      kind.icon,
                      size: 64,
                      color: theme.colorScheme.primary.withAlpha(80),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No ${kind.noun.toLowerCase()}s',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isTrigger
                          ? 'Tap + to add a trigger.'
                          : 'Tap + to add a rule, or restore the bundled defaults.',
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
                  if (_isTrigger)
                    const _TriggerIdleBanner()
                  else
                    const _ShortcutHintBanner(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: rules.length,
                      itemBuilder: (context, index) {
                        final rule = rules[index];
                        return _RuleTile(
                          rule: rule,
                          icon: kind.icon,
                          onToggleFavorite: _isTrigger
                              ? () => ref
                                  .read(kind.provider.notifier)
                                  .toggleFavorite(rule.id)
                              : null,
                          onToggle: () => ref
                              .read(kind.provider.notifier)
                              .toggleRule(rule.id),
                          onEdit: () => _openEditor(context, rule),
                          onDelete: () {
                            ref
                                .read(kind.provider.notifier)
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
    openTextLinkRuleEditor(context, existing: existing, kind: kind);
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
    if (_isTrigger) {
      _showTriggerHelpDialog(context);
      return;
    }
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

  void _showTriggerHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('About Command Triggers'),
        content: const SingleChildScrollView(
          child: Text(
            'A command trigger sends its command by itself when a line of '
            'MUD output matches its pattern. Patterns and templates work '
            'exactly like text link rules.\n\n'
            'Triggers only fire once you have left the client alone for 3 '
            'seconds: no typing, tapping or scrolling. A match is sent 1 '
            'second later, and touching the client in that second cancels '
            'it. After a trigger fires, no trigger fires for 3 seconds, so '
            'a burst of matching lines sends one command.\n\n'
            'Star a trigger to put an on/off switch for it in the floating '
            'Favourite Triggers panel over the terminal.\n\n'
            'The Instant Triggers toggle in the toolbar (desktop) turns all '
            'of that off: while it is on, a match fires at once, even while '
            'you are typing, up to 2 triggers in any 1 second; matches over '
            'that are dropped. It resets to off on every launch.\n\n'
            'This is a local-only feature, enabled by the file '
            '$localFeaturesMarkerAsset in your checkout.',
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

/// Opens the text-link-rule create/edit screen as a pushed route.
///
/// Pass [existing] to edit a rule, or [initialMatchText] to start a brand-new
/// rule seeded from a piece of MUD output — used by the terminal's
/// "Create Text Link Rule" context-menu action. The seed's first line is
/// regex-escaped into the Pattern field (so it matches literally by default)
/// and dropped verbatim into the Test input so the live preview is ready as
/// soon as the user fills in a command.
Future<void> openTextLinkRuleEditor(
  BuildContext context, {
  TextLinkRule? existing,
  String? initialMatchText,
  RuleListKind kind = RuleListKind.textLink,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _TextLinkRuleEditScreen(
        existing: existing,
        initialMatchText: initialMatchText,
        kind: kind,
      ),
    ),
  );
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

/// The command-trigger counterpart of [_ShortcutHintBanner]: says when
/// triggers are allowed to act.
class _TriggerIdleBanner extends StatelessWidget {
  const _TriggerIdleBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.primary.withAlpha(20),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Fire 1s after a match, after 3s without input; 3s cooldown.',
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
  final IconData icon;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Null hides the star (text link rules have no favourites).
  final VoidCallback? onToggleFavorite;

  const _RuleTile({
    required this.rule,
    required this.icon,
    this.onToggleFavorite,
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
        compiles ? icon : Icons.error_outline,
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
          if (onToggleFavorite != null)
            IconButton(
              icon: Icon(
                rule.favorite ? Icons.star : Icons.star_border,
                color: rule.favorite ? Colors.amber : null,
              ),
              tooltip: rule.favorite ? 'Unfavourite' : 'Favourite',
              onPressed: onToggleFavorite,
            ),
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

  /// Selected MUD-output text to seed a brand-new rule from. Ignored when
  /// [existing] is set (editing an existing rule wins).
  final String? initialMatchText;

  final RuleListKind kind;

  const _TextLinkRuleEditScreen({
    this.existing,
    this.initialMatchText,
    required this.kind,
  });

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
  late bool _skipInCombat;
  late bool _skipWhileMoving;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _skipInCombat = e?.skipInCombat ?? false;
    _skipWhileMoving = e?.skipWhileMoving ?? true;

    // When creating a rule from selected MUD output, seed the Pattern with
    // the regex-escaped first line (literal match by default) and the Test
    // input with that same line so the preview lights up once a command is
    // entered. Rules match per-line, so a multi-line selection is reduced to
    // its first line.
    final seed = e == null ? widget.initialMatchText : null;
    final seedLine =
        (seed != null && seed.trim().isNotEmpty) ? seed.split('\n').first : '';

    _nameController = TextEditingController(text: e?.name ?? '');
    _patternController = TextEditingController(
      text: e?.pattern ?? (seedLine.isEmpty ? '' : RegExp.escape(seedLine)),
    );
    _commandController =
        TextEditingController(text: e?.commandTemplate ?? '');
    _testController = TextEditingController(text: seedLine);
  }

  String _defaultName() =>
      ref.read(widget.kind.provider.notifier).nextDefaultName('Trigger');

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
    var name = _nameController.text.trim();
    final pattern = _patternController.text.trim();
    final command = _commandController.text.trim();
    if (name.isEmpty && widget.kind.nameOptional) {
      name = widget.existing?.name ?? _defaultName();
    }

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
          '${widget.kind.idPrefix}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      pattern: pattern,
      commandTemplate: command,
      enabled: widget.existing?.enabled ?? true,
      caseSensitive: widget.existing?.caseSensitive ?? true,
      favorite: widget.existing?.favorite ?? false,
      skipInCombat: _skipInCombat,
      skipWhileMoving: _skipWhileMoving,
    );

    final notifier = ref.read(widget.kind.provider.notifier);
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
    // Watched so the hint catches up once the list has loaded from disk.
    ref.watch(widget.kind.provider);

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(
          '${isEditing ? 'Edit' : 'New'} ${widget.kind.noun}',
        ),
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
            decoration: InputDecoration(
              labelText: widget.kind.nameOptional ? 'Name (optional)' : 'Name',
              hintText: widget.kind.nameOptional
                  ? 'Defaults to ${_defaultName()}'
                  : 'e.g., Open closed door',
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
          if (widget.kind == RuleListKind.commandTrigger) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Not during combat'),
              subtitle: const Text("Don't fire while a fight is going on"),
              value: _skipInCombat,
              onChanged: (v) => setState(() => _skipInCombat = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Not while moving'),
              subtitle: const Text(
                "Don't fire for 2 s after a movement command, so you don't "
                'act on rooms you are only passing through',
              ),
              value: _skipWhileMoving,
              onChanged: (v) => setState(() => _skipWhileMoving = v),
            ),
          ],
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
    return EscapeDismiss(child: scaffold);
  }
}
