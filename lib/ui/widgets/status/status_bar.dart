import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/game_state.dart';
import '../../../providers/game_state_provider.dart';
import 'vitals_gauge.dart';

/// Status bar showing player vitals (HP, SP), coordinates, and area info.
///
/// On mobile, starts collapsed as a thin strip and expands on tap.
/// On desktop, shows the full panel permanently.
class StatusBar extends ConsumerStatefulWidget {
  /// If true, starts collapsed (for mobile layout).
  final bool collapsible;

  const StatusBar({super.key, this.collapsible = false});

  @override
  ConsumerState<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends ConsumerState<StatusBar> {
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.collapsible;
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final theme = Theme.of(context);

    if (!gameState.hasVitals) {
      return const SizedBox.shrink();
    }

    if (widget.collapsible && !_expanded) {
      return _buildCollapsed(gameState, theme);
    }

    return _buildExpanded(gameState, theme);
  }

  /// Collapsed view: thin strip with HP/SP bars and area name.
  Widget _buildCollapsed(GameState state, ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: _barDecoration(theme),
        child: Row(
          children: [
            // HP mini bar.
            _MiniBar(
              label: 'HP',
              fraction: state.hpFraction,
              color: _hpColor(state.hpFraction),
            ),
            const SizedBox(width: 8),
            Text(
              '${state.hp}',
              style: _miniTextStyle(theme),
            ),
            const SizedBox(width: 16),

            // SP mini bar.
            _MiniBar(
              label: 'SP',
              fraction: state.spFraction,
              color: const Color(0xFF4488FF),
            ),
            const SizedBox(width: 8),
            Text(
              '${state.sp}',
              style: _miniTextStyle(theme),
            ),

            const Spacer(),

            // Area name.
            if (state.currentArea != null)
              Text(
                state.currentArea!,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                ),
              ),

            const SizedBox(width: 8),
            Icon(
              Icons.expand_less,
              size: 16,
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
          ],
        ),
      ),
    );
  }

  /// Expanded view: full gauges, coordinates, player info.
  Widget _buildExpanded(GameState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: _barDecoration(theme),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapse button (mobile only).
          if (widget.collapsible)
            GestureDetector(
              onTap: () => setState(() => _expanded = false),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.expand_more,
                    size: 16,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ],
              ),
            ),

          // HP gauge.
          VitalsGauge(
            label: 'HP',
            value: state.hp,
            maxValue: state.maxHp,
            icon: Icons.favorite,
            gradientColors: [
              _hpColor(state.hpFraction).withAlpha(180),
              _hpColor(state.hpFraction),
            ],
          ),
          const SizedBox(height: 6),

          // SP gauge.
          VitalsGauge(
            label: 'SP',
            value: state.sp,
            maxValue: state.maxSp,
            icon: Icons.auto_awesome,
            gradientColors: const [
              Color(0xFF2255AA),
              Color(0xFF4488FF),
            ],
          ),
          const SizedBox(height: 8),

          // Info row: coordinates, area, player info.
          Row(
            children: [
              // Coordinates.
              if (state.hasCoordinates) ...[
                Icon(Icons.explore, size: 14,
                    color: theme.colorScheme.onSurface.withAlpha(140)),
                const SizedBox(width: 4),
                Text(
                  '(${state.x}, ${state.y})',
                  style: _infoTextStyle(theme),
                ),
                const SizedBox(width: 12),
              ],

              // Area.
              if (state.currentArea != null) ...[
                Icon(Icons.map, size: 14,
                    color: theme.colorScheme.primary.withAlpha(180)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    state.currentArea!,
                    style: _infoTextStyle(theme).copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const Spacer(),

              // XP.
              if (state.xp != null) ...[
                Text(
                  'XP: ${_formatNumber(state.xp!)}',
                  style: _infoTextStyle(theme).copyWith(
                    color: const Color(0xFFD4A057),
                  ),
                ),
              ],
            ],
          ),

          // Player info row.
          if (state.playerName != null || state.coins != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if (state.playerName != null) ...[
                    Text(
                      state.playerName!,
                      style: _infoTextStyle(theme).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (state.playerClass != null) ...[
                      Text(
                        ' the ${state.playerClass}',
                        style: _infoTextStyle(theme),
                      ),
                    ],
                  ],
                  const Spacer(),
                  if (state.coins != null) ...[
                    Icon(Icons.monetization_on, size: 12,
                        color: const Color(0xFFD4A057).withAlpha(180)),
                    const SizedBox(width: 3),
                    Text(
                      _formatNumber(state.coins!),
                      style: _infoTextStyle(theme).copyWith(
                        color: const Color(0xFFD4A057),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _barDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surface.withAlpha(230),
      border: Border(
        top: BorderSide(
          color: theme.colorScheme.primary.withAlpha(40),
        ),
      ),
    );
  }

  TextStyle _miniTextStyle(ThemeData theme) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 11,
      color: theme.colorScheme.onSurface.withAlpha(200),
    );
  }

  TextStyle _infoTextStyle(ThemeData theme) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 11,
      color: theme.colorScheme.onSurface.withAlpha(160),
    );
  }

  /// HP bar color changes based on remaining health fraction.
  Color _hpColor(double fraction) {
    if (fraction > 0.6) return const Color(0xFF44AA44); // Green
    if (fraction > 0.3) return const Color(0xFFCC8800); // Orange
    return const Color(0xFFCC2222); // Red
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

/// Tiny inline progress bar for the collapsed status view.
class _MiniBar extends StatelessWidget {
  final String label;
  final double fraction;
  final Color color;

  const _MiniBar({
    required this.label,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 40,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.black26,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}
