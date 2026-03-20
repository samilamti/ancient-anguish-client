import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/terminal_block.dart';
import '../../../models/trigger_rule.dart';
import '../../../providers/trigger_provider.dart';
import '../../screens/trigger_settings_screen.dart';

/// Floating action bar shown on hover over a terminal block.
class BlockActionBar extends ConsumerWidget {
  final TerminalBlock block;

  const BlockActionBar({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(6),
      color: theme.colorScheme.surface.withAlpha(230),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: Icons.copy_rounded,
              tooltip: 'Copy Block',
              onPressed: () => _copyBlock(context),
            ),
            _ActionButton(
              icon: Icons.highlight_rounded,
              tooltip: 'Add Immersion',
              onPressed: () => _addImmersion(context),
            ),
            _ActionButton(
              icon: Icons.visibility_off_rounded,
              tooltip: 'Gag',
              onPressed: () => _showGagDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _copyBlock(BuildContext context) {
    Clipboard.setData(ClipboardData(text: block.plainText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Block copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _addImmersion(BuildContext context) {
    final pattern = _suggestPattern();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TriggerEditScreen(
          existing: TriggerRule(
            id: '',
            name: '',
            pattern: pattern,
            action: TriggerAction.highlight,
          ),
        ),
      ),
    );
  }

  void _showGagDialog(BuildContext context, WidgetRef ref) {
    final pattern = _suggestPattern();
    final controller = TextEditingController(text: pattern);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quick Gag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Pattern to gag',
            helperText: 'Lines matching this regex will be hidden',
          ),
          maxLines: 3,
          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final rule = TriggerRule(
                id: 'gag_${DateTime.now().millisecondsSinceEpoch}',
                name: 'Gag: ${text.length > 30 ? '${text.substring(0, 30)}...' : text}',
                pattern: text,
                action: TriggerAction.gag,
              );
              ref.read(triggerRulesProvider.notifier).addRule(rule);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gag rule created'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Create Gag'),
          ),
        ],
      ),
    );
    // Dispose controller when dialog closes.
    controller.addListener(() {});
  }

  String _suggestPattern() {
    for (final line in block.lines) {
      final text = line.plainText.trim();
      if (text.isNotEmpty) return RegExp.escape(text);
    }
    return '';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: const EdgeInsets.all(4),
      splashRadius: 14,
      visualDensity: VisualDensity.compact,
    );
  }
}
