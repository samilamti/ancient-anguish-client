import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/text_link_rule.dart';
import '../../models/trigger_rule.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/text_link_rule_provider.dart';
import '../../providers/trigger_provider.dart';

/// Opens the Kill-picker "Customise" designer for [target].
///
/// The designer captures an ordered list of combat steps and, on save, wires
/// up three coordinated pieces of automation for the target (example
/// `badger` → alias `_k_badger`):
///   1. A MUD-side alias sent to the server: `alias _k_badger do <steps…>`.
///   2. A Text Link Rule so the word lights up as a tappable link that sends
///      `_k_badger` (the MUD expands it).
///   3. An Immersion (highlight trigger) that colours the word red and bold.
Future<void> openKillAliasDesigner(
  BuildContext context, {
  required String target,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _KillAliasDesignerScreen(target: target),
    ),
  );
}

/// The Kill-picker red used to highlight a customised target. Matches the
/// "Red" swatch in the Immersion editor's palette.
const Color _killHighlightColor = Color(0xFFFF0000);

class _KillAliasDesignerScreen extends ConsumerStatefulWidget {
  final String target;

  const _KillAliasDesignerScreen({required this.target});

  @override
  ConsumerState<_KillAliasDesignerScreen> createState() =>
      _KillAliasDesignerScreenState();
}

class _KillAliasDesignerScreenState
    extends ConsumerState<_KillAliasDesignerScreen> {
  final List<TextEditingController> _stepControllers = [];

  /// Normalized target used for the storage key and derived identifiers.
  late final String _normalized = AppSettings.normalizeTarget(widget.target);

  /// MUD alias name, e.g. `_k_badger`. Whitespace in multi-word targets
  /// collapses to underscores so the name is a single token.
  late final String _aliasName =
      '_k_${_normalized.replaceAll(RegExp(r'\s+'), '_')}';

  @override
  void initState() {
    super.initState();
    final saved = ref.read(settingsProvider.notifier).killAliasStepsFor(
          widget.target,
        );
    if (saved.isEmpty) {
      _addStep();
    } else {
      for (final step in saved) {
        _addStep(step);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _stepControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addStep([String text = '']) {
    final controller = TextEditingController(text: text);
    controller.addListener(_onStepsChanged);
    setState(() => _stepControllers.add(controller));
  }

  void _removeStep(int index) {
    final controller = _stepControllers.removeAt(index);
    controller.removeListener(_onStepsChanged);
    controller.dispose();
    setState(() {});
  }

  void _onStepsChanged() => setState(() {});

  /// Non-empty, trimmed steps in row order.
  List<String> get _steps => _stepControllers
      .map((c) => c.text.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  String get _scriptPreview => 'alias $_aliasName do ${_steps.join(',')}';

  void _save() {
    final steps = _steps;
    if (steps.isEmpty) return;

    // 1. Persist steps so re-opening the designer repopulates the rows.
    ref.read(settingsProvider.notifier).setKillAliasSteps(widget.target, steps);

    // 2. Send the MUD-side alias (or warn if offline — still saved locally).
    final script = 'alias $_aliasName do ${steps.join(',')}';
    final connection = ref.read(connectionServiceProvider);
    final buffer = ref.read(terminalBufferProvider.notifier);
    if (connection.isConnected) {
      connection.sendCommand(script);
      buffer.addLocalLine('Sent: $script');
    } else {
      buffer.addLocalLine(
        'Not connected — alias saved locally but not sent to MUD.',
        isError: true,
      );
    }

    // Whole-word, case-insensitive pattern shared by the link rule + immersion.
    final pattern = '\\b${RegExp.escape(widget.target)}\\b';

    // 3. Upsert the Text Link Rule: tapping the word sends the raw alias name.
    final tlrId = 'tlr_kill_$_normalized';
    final tlrNotifier = ref.read(textLinkRulesProvider.notifier);
    final tlrExists =
        ref.read(textLinkRulesProvider).any((r) => r.id == tlrId);
    final tlr = TextLinkRule(
      id: tlrId,
      name: 'Kill ${widget.target}',
      pattern: pattern,
      commandTemplate: _aliasName,
      caseSensitive: false,
      enabled: true,
    );
    if (tlrExists) {
      tlrNotifier.updateRule(tlr);
    } else {
      tlrNotifier.addRule(tlr);
    }

    // 4. Upsert the Immersion: colour the word red + bold.
    final trigId = 'trigger_kill_$_normalized';
    final trigNotifier = ref.read(triggerRulesProvider.notifier);
    final trigExists =
        ref.read(triggerRulesProvider).any((r) => r.id == trigId);
    final trigger = TriggerRule(
      id: trigId,
      name: 'Kill ${widget.target}',
      pattern: pattern,
      action: TriggerAction.highlight,
      highlightForeground: _killHighlightColor,
      highlightBold: true,
      highlightWholeLine: false,
      enabled: true,
    );
    if (trigExists) {
      trigNotifier.updateRule(trigger);
    } else {
      trigNotifier.addRule(trigger);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = _steps.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Customise "${widget.target}"'),
        actions: [
          TextButton.icon(
            onPressed: canSave ? _save : null,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Build a reusable combat sequence for this target. Each step runs '
            'in order when the alias fires.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(170),
            ),
          ),
          const SizedBox(height: 12),
          _InfoChip(
            icon: Icons.terminal,
            label: 'Alias',
            value: _aliasName,
            theme: theme,
          ),
          const SizedBox(height: 20),
          Text('Steps', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < _stepControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stepControllers[i],
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(fontFamily: 'JetBrainsMono'),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: i == 0 ? 'e.g. link \$*' : 'command',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    tooltip: 'Remove step',
                    onPressed: _stepControllers.length > 1
                        ? () => _removeStep(i)
                        : null,
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addStep(),
              icon: const Icon(Icons.add),
              label: const Text('Add step'),
            ),
          ),
          const SizedBox(height: 20),
          Text('Will send', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _scriptPreview,
              style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Saving also makes "${widget.target}" a tappable link (sends '
            '$_aliasName) and highlights it red & bold in the terminal.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(170),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text('$label: ', style: theme.textTheme.bodyMedium),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
