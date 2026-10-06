import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/command_trigger_provider.dart';

/// Floating window over the terminal with an on/off switch for every starred
/// command trigger, so they can be flipped mid-fight without opening the
/// rules screen. Local-only, like command triggers themselves; hidden while
/// nothing is starred.
///
/// Fill the terminal's Stack with it: empty space passes taps through, and
/// the panel is dragged by its title bar and kept inside the terminal.
class FavoriteTriggersOverlay extends ConsumerStatefulWidget {
  const FavoriteTriggersOverlay({super.key});

  @override
  ConsumerState<FavoriteTriggersOverlay> createState() =>
      _FavoriteTriggersOverlayState();
}

class _FavoriteTriggersOverlayState
    extends ConsumerState<FavoriteTriggersOverlay> {
  static const _width = 220.0;

  /// Top-left of the panel. Below the notification strip, clear of the
  /// compass in the top-right corner.
  Offset _offset = const Offset(12, 40);
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(localFeaturesAvailableProvider).value ?? false;
    if (!available) return const SizedBox.shrink();
    final favorites = ref
        .watch(commandTriggerRulesProvider)
        .where((r) => r.favorite)
        .toList();
    if (favorites.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final maxX = (constraints.maxWidth - _width).clamp(0.0, double.infinity);
      final maxY = (constraints.maxHeight - 32).clamp(0.0, double.infinity);
      final pos = Offset(
        _offset.dx.clamp(0.0, maxX),
        _offset.dy.clamp(0.0, maxY),
      );

      return Stack(
        children: [
          Positioned(
            left: pos.dx,
            top: pos.dy,
            width: _width,
            // ExcludeFocus: flipping a switch must not pull focus out of the
            // command input.
            child: ExcludeFocus(
              child: Material(
                key: const ValueKey('favoriteTriggersPanel'),
                elevation: 6,
                color: theme.colorScheme.surface.withAlpha(235),
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onPanUpdate: (d) =>
                          setState(() => _offset = pos + d.delta),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.only(left: 8),
                        color: theme.colorScheme.primary.withAlpha(40),
                        child: Row(
                          children: [
                            const Icon(Icons.star,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Triggers',
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                            IconButton(
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              tooltip: _collapsed ? 'Expand' : 'Collapse',
                              icon: Icon(_collapsed
                                  ? Icons.expand_more
                                  : Icons.expand_less),
                              onPressed: () =>
                                  setState(() => _collapsed = !_collapsed),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_collapsed)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: (constraints.maxHeight - pos.dy - 32)
                              .clamp(48.0, 360.0),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          children: [
                            for (final rule in favorites)
                              _FavoriteRow(
                                name: rule.name,
                                command: rule.commandTemplate,
                                enabled: rule.enabled,
                                onToggle: () => ref
                                    .read(commandTriggerRulesProvider.notifier)
                                    .toggleRule(rule.id),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _FavoriteRow extends StatelessWidget {
  final String name;
  final String command;
  final bool enabled;
  final VoidCallback onToggle;

  const _FavoriteRow({
    required this.name,
    required this.command,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurface.withAlpha(enabled ? 150 : 80);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                  Text(
                    '→ $command',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: dim,
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.75,
              child: Switch(value: enabled, onChanged: (_) => onToggle()),
            ),
          ],
        ),
      ),
    );
  }
}
