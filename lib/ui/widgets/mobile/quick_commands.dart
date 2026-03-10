import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connection_provider.dart';

/// A configurable grid of quick-command buttons for mobile users.
///
/// Provides fast access to common MUD commands (movement, look, inventory, etc.)
/// without needing to type them. Displayed above the keyboard on mobile layouts.
class QuickCommands extends ConsumerWidget {
  const QuickCommands({super.key});

  // Default command sets – user will be able to customize these in Phase 4.
  static const List<_QuickCmd> _defaultCommands = [
    _QuickCmd('N', 'north'),
    _QuickCmd('S', 'south'),
    _QuickCmd('E', 'east'),
    _QuickCmd('W', 'west'),
    _QuickCmd('U', 'up'),
    _QuickCmd('D', 'down'),
    _QuickCmd('Look', 'look'),
    _QuickCmd('Inv', 'inventory'),
    _QuickCmd('Score', 'score'),
    _QuickCmd('Who', 'who'),
    _QuickCmd('Flee', 'flee'),
    _QuickCmd('Map', 'map'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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
        children: _defaultCommands.map((cmd) {
          return _QuickCommandButton(
            label: cmd.label,
            onPressed: () {
              ref.read(connectionServiceProvider).sendCommand(cmd.command);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _QuickCmd {
  final String label;
  final String command;
  const _QuickCmd(this.label, this.command);
}

class _QuickCommandButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _QuickCommandButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
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
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
