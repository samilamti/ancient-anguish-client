import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/quick_command.dart';
import '../../../providers/connection_provider.dart';
import '../../../providers/recent_words_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/quick_command_icons.dart';
import 'target_picker_sheet.dart';

/// A configurable row of quick-command buttons for mobile users.
///
/// Provides fast access to common MUD commands without needing to type them.
/// The first button is always a keyboard toggle; the rest come from
/// [AppSettings.quickCommands]. A `selectTarget` command opens a bottom
/// sheet of recent words and sends the command plus the chosen target.
class QuickCommands extends ConsumerWidget {
  const QuickCommands({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final commands = ref.watch(settingsProvider
        .select((s) => s.quickCommands.where((c) => c.enabled).toList()));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(200),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withAlpha(40),
          ),
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _QuickCommandButton(
            tooltip: 'Show keyboard',
            icon: Icons.keyboard,
            onPressed: () {
              ref.read(inputFocusProvider).requestFocus();
            },
          ),
          for (final cmd in commands)
            _QuickCommandButton(
              tooltip: cmd.label,
              icon: iconFromName(cmd.iconName),
              onPressed: () => _handleCommand(context, ref, cmd),
            ),
        ],
      ),
    );
  }

  Future<void> _handleCommand(
    BuildContext context,
    WidgetRef ref,
    QuickCommand cmd,
  ) async {
    final service = ref.read(connectionServiceProvider);

    if (!cmd.selectTarget) {
      service.sendCommand(cmd.command);
      return;
    }

    final words = ref.read(recentWordsProvider);
    if (words.isEmpty) {
      // No targets to pick from — pre-fill the input and open the keyboard.
      final controller = ref.read(inputControllerProvider);
      final prefix = '${cmd.command} ';
      controller.text = prefix;
      controller.selection = TextSelection.collapsed(offset: prefix.length);
      ref.read(inputFocusProvider).requestFocus();
      return;
    }

    final chosen = await TargetPickerSheet.show(
      context,
      commandLabel: cmd.label,
    );
    if (chosen == null || chosen.isEmpty) return;
    service.sendCommand('${cmd.command} $chosen');
  }
}

class _QuickCommandButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _QuickCommandButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: theme.colorScheme.primary.withAlpha(80),
              ),
            ),
            minimumSize: const Size(44, 36),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
