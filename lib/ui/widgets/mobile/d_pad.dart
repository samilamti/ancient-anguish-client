import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connection_provider.dart';
import '../../../providers/game_state_provider.dart';

/// A compass-rose directional pad for mobile navigation.
///
/// Provides 8 compass directions (N, NE, E, SE, S, SW, W, NW) plus Up/Down
/// in a circular layout optimized for thumb access on mobile devices.
class DPad extends ConsumerWidget {
  const DPad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    void send(String command) {
      ref.read(connectionServiceProvider).sendCommand(command);
      ref.read(gameStateProvider.notifier).recordDirectionalAttempt(command);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(200),
        border: Border(
          top: BorderSide(color: theme.colorScheme.primary.withAlpha(40)),
        ),
      ),
      child: Row(
        children: [
          // Compass rose.
          Expanded(
            child: _CompassRose(onDirection: send),
          ),

          const SizedBox(width: 8),

          // Up / Down / Look column.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DPadButton(
                label: 'Up',
                icon: Icons.arrow_upward,
                onPressed: () => send('up'),
              ),
              const SizedBox(height: 4),
              _DPadButton(
                label: 'Look',
                icon: Icons.visibility,
                onPressed: () => send('look'),
              ),
              const SizedBox(height: 4),
              _DPadButton(
                label: 'Down',
                icon: Icons.arrow_downward,
                onPressed: () => send('down'),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // Quick action column.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DPadButton(
                label: 'Inv',
                icon: Icons.backpack,
                onPressed: () => send('inventory'),
              ),
              const SizedBox(height: 4),
              _DPadButton(
                label: 'Score',
                icon: Icons.star,
                onPressed: () => send('score'),
              ),
              const SizedBox(height: 4),
              _DPadButton(
                label: 'Flee',
                icon: Icons.directions_run,
                onPressed: () => send('flee'),
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The 8-direction compass rose widget.
class _CompassRose extends StatelessWidget {
  final void Function(String command) onDirection;

  const _CompassRose({required this.onDirection});

  @override
  Widget build(BuildContext context) {
    // 3x3 grid layout for the compass.
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        TableRow(children: [
          _DPadButton(
            label: 'NW',
            onPressed: () => onDirection('northwest'),
            compact: true,
          ),
          _DPadButton(
            label: 'N',
            icon: Icons.north,
            onPressed: () => onDirection('north'),
          ),
          _DPadButton(
            label: 'NE',
            onPressed: () => onDirection('northeast'),
            compact: true,
          ),
        ]),
        TableRow(children: [
          _DPadButton(
            label: 'W',
            icon: Icons.west,
            onPressed: () => onDirection('west'),
          ),
          // Center: compass indicator.
          _CompassCenter(),
          _DPadButton(
            label: 'E',
            icon: Icons.east,
            onPressed: () => onDirection('east'),
          ),
        ]),
        TableRow(children: [
          _DPadButton(
            label: 'SW',
            onPressed: () => onDirection('southwest'),
            compact: true,
          ),
          _DPadButton(
            label: 'S',
            icon: Icons.south,
            onPressed: () => onDirection('south'),
          ),
          _DPadButton(
            label: 'SE',
            onPressed: () => onDirection('southeast'),
            compact: true,
          ),
        ]),
      ],
    );
  }
}

/// The center piece of the compass rose.
///
/// Shows the current area name when known, or a compass icon otherwise.
class _CompassCenter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final areaName = ref.watch(
      gameStateProvider.select((s) => s.currentArea),
    );

    return Padding(
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        width: 44,
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary.withAlpha(60),
            ),
          ),
          child: areaName != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      areaName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                )
              : Icon(
                  Icons.explore,
                  size: 20,
                  color: theme.colorScheme.primary.withAlpha(120),
                ),
        ),
      ),
    );
  }
}

/// A single direction button on the D-Pad.
class _DPadButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool compact;
  final Color? color;

  const _DPadButton({
    required this.label,
    this.icon,
    required this.onPressed,
    this.compact = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        width: compact ? 40 : 44,
        height: compact ? 36 : 44,
        child: Material(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: buttonColor.withAlpha(80)),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: icon != null && !compact
                  ? Icon(icon, size: 18, color: buttonColor)
                  : Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.bold,
                        color: buttonColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
