import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/battle_provider.dart';
import '../../../providers/game_state_provider.dart';
import '../../../providers/unified_area_config_provider.dart';
import 'vitals_gauge.dart';

/// Shows a dialog to rename the current area. Shared by status bar and D-pad.
Future<void> showRenameAreaDialog(BuildContext context, WidgetRef ref) async {
  final gameState = ref.read(gameStateProvider);
  final currentName = gameState.currentArea;
  if (currentName == null || !gameState.hasCoordinates) return;

  final controller = TextEditingController(text: currentName);
  final newName = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename area'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter new name...',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.of(ctx).pop(v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final n = controller.text.trim();
            if (n.isNotEmpty) Navigator.of(ctx).pop(n);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (newName == null || newName.isEmpty || newName == currentName) return;

  final config = ref.read(unifiedAreaConfigProvider).value;
  if (config == null) return;
  config.renameArea(currentName, newName);
  ref.read(gameStateProvider.notifier).setCurrentArea(newName);
}

/// HP and SP bars displayed side by side at the top of the screen.
class VitalsRow extends ConsumerWidget {
  const VitalsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final theme = Theme.of(context);

    if (!gameState.hasVitals) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(230),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withAlpha(40),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HP gauge.
          Expanded(
            child: VitalsGauge(
              label: 'HP',
              value: gameState.hp,
              maxValue: gameState.maxHp,
              icon: Icons.favorite,
              gradientColors: [
                _hpColor(gameState.hpFraction).withAlpha(180),
                _hpColor(gameState.hpFraction),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // SP gauge.
          Expanded(
            child: VitalsGauge(
              label: 'SP',
              value: gameState.sp,
              maxValue: gameState.maxSp,
              icon: Icons.auto_awesome,
              gradientColors: const [
                Color(0xFF2255AA),
                Color(0xFF4488FF),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _hpColor(double fraction) {
    if (fraction > 0.6) return const Color(0xFF44AA44);
    if (fraction > 0.3) return const Color(0xFFCC8800);
    return const Color(0xFFCC2222);
  }
}

/// Status bar showing coordinates, area, and player info.
///
/// HP/SP gauges are shown separately by [VitalsRow].
class StatusBar extends ConsumerStatefulWidget {
  const StatusBar({super.key});

  @override
  ConsumerState<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends ConsumerState<StatusBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onNameAreaPressed() {
    final battleState = ref.read(battleStateProvider);
    if (battleState.inBattle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot name areas during battle — wait until '
              'combat ends.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    _showNameAreaDialog();
  }

  void _showNameAreaDialog() {
    final controller = TextEditingController();
    showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Name this area'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter area name...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop(name);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((name) {
      controller.dispose();
      if (name != null && name.isNotEmpty && mounted) {
        _saveArea(name);
      }
    });
  }

  void _saveArea(String name) {
    final gameState = ref.read(gameStateProvider);
    if (!gameState.hasCoordinates) return;

    final config = ref.read(unifiedAreaConfigProvider).value;
    if (config == null) return;

    config.addCoordinateToArea(name, gameState.x!, gameState.y!);
    ref.read(gameStateProvider.notifier).setCurrentArea(name);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final theme = Theme.of(context);

    // Only show when we have coordinates or player info.
    if (!gameState.hasCoordinates &&
        gameState.currentArea == null &&
        gameState.playerName == null &&
        gameState.xp == null &&
        gameState.coins == null) {
      return const SizedBox.shrink();
    }

    // Show naming prompt when at unmapped coords for 3+ directional moves.
    final canNameArea = gameState.hasCoordinates &&
        gameState.currentArea == null &&
        gameState.directionalMovesAtSameCoords >= 3;

    // Drive the pulse animation based on whether the button should show.
    if (canNameArea) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(230),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withAlpha(40),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Info row: coordinates, area, XP.
          Row(
            children: [
              if (gameState.hasCoordinates) ...[
                Icon(Icons.explore, size: 14,
                    color: theme.colorScheme.onSurface.withAlpha(140)),
                const SizedBox(width: 4),
                Text(
                  '(${gameState.x}, ${gameState.y})',
                  style: _infoTextStyle(theme),
                ),
                const SizedBox(width: 12),
              ],
              if (gameState.currentArea != null) ...[
                Flexible(
                  child: Tooltip(
                    message: 'Click to rename',
                    child: InkWell(
                      onTap: () => showRenameAreaDialog(context, ref),
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map, size: 14,
                              color: theme.colorScheme.primary.withAlpha(180)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              gameState.currentArea!,
                              style: _infoTextStyle(theme).copyWith(
                                color: theme.colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (canNameArea) ...[
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Material(
                    color: const Color(0xFFD4A057),
                    borderRadius: BorderRadius.circular(16),
                    elevation: 2,
                    child: InkWell(
                      onTap: _onNameAreaPressed,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_location_alt, size: 14,
                                color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Name this area',
                              style: _infoTextStyle(theme).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (gameState.xp != null)
                Text(
                  'XP: ${_formatNumber(gameState.xp!)}',
                  style: _infoTextStyle(theme).copyWith(
                    color: const Color(0xFFD4A057),
                  ),
                ),
            ],
          ),

          // Player info row.
          if (gameState.coins != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Spacer(),
                  Icon(Icons.monetization_on, size: 12,
                      color: const Color(0xFFD4A057).withAlpha(180)),
                  const SizedBox(width: 3),
                  Text(
                    _formatNumber(gameState.coins!),
                    style: _infoTextStyle(theme).copyWith(
                      color: const Color(0xFFD4A057),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _infoTextStyle(ThemeData theme) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 11,
      color: theme.colorScheme.onSurface.withAlpha(160),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
