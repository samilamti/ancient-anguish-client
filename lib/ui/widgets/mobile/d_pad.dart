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

          // Vertical column: Up / Down / Score.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DPadButton(
                label: 'Up',
                emoji: '🛫',
                onPressed: () => send('up'),
              ),
              const SizedBox(height: 4),
              _DPadButton(
                label: 'Down',
                emoji: '🛬',
                onPressed: () => send('down'),
              ),
              const SizedBox(height: 4),
              _DPadButton(
                label: 'Score',
                icon: Icons.star,
                onPressed: () => send('score'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The 8-direction compass rose widget. The center cell doubles as a Look
/// button so the user can re-render the current room without leaving the
/// D-Pad.
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
            emoji: '↖️',
            onPressed: () => onDirection('northwest'),
            compact: true,
          ),
          _DPadButton(
            label: 'N',
            emoji: '⬆️',
            onPressed: () => onDirection('north'),
          ),
          _DPadButton(
            label: 'NE',
            emoji: '↗️',
            onPressed: () => onDirection('northeast'),
            compact: true,
          ),
        ]),
        TableRow(children: [
          _DPadButton(
            label: 'W',
            emoji: '⬅️',
            onPressed: () => onDirection('west'),
          ),
          _DPadButton(
            label: 'Look',
            emoji: '👀',
            onPressed: () => onDirection('look'),
          ),
          _DPadButton(
            label: 'E',
            emoji: '➡️',
            onPressed: () => onDirection('east'),
          ),
        ]),
        TableRow(children: [
          _DPadButton(
            label: 'SW',
            emoji: '↙️',
            onPressed: () => onDirection('southwest'),
            compact: true,
          ),
          _DPadButton(
            label: 'S',
            emoji: '⬇️',
            onPressed: () => onDirection('south'),
          ),
          _DPadButton(
            label: 'SE',
            emoji: '↘️',
            onPressed: () => onDirection('southeast'),
            compact: true,
          ),
        ]),
      ],
    );
  }
}

/// A single direction button on the D-Pad.
///
/// Exactly one of [emoji] or [icon] should be provided; [label] is always
/// used for the tooltip/semantic text even when a glyph is shown.
class _DPadButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? emoji;
  final VoidCallback onPressed;
  final bool compact;

  const _DPadButton({
    required this.label,
    this.icon,
    this.emoji,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = theme.colorScheme.primary;

    final Widget child;
    if (emoji != null) {
      child = Text(
        emoji!,
        style: TextStyle(fontSize: compact ? 18 : 22, height: 1.0),
      );
    } else if (icon != null) {
      child = Icon(icon, size: 18, color: buttonColor);
    } else {
      child = Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.bold,
          color: buttonColor,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Tooltip(
        message: label,
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
              onTap: () {
                // Hide the soft keyboard when moving around so the room text
                // isn't occluded by it.
                FocusManager.instance.primaryFocus?.unfocus();
                onPressed();
              },
              borderRadius: BorderRadius.circular(8),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
