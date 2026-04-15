import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/game_state_provider.dart';

/// Displays survival/condition stats as color-coded icon chips.
///
/// Green when value is low (healthy), yellow when moderate, red when critical.
class SurvivalPanel extends ConsumerWidget {
  const SurvivalPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
    if (!gs.hasSurvivalStats) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final chips = <Widget>[];

    if (gs.stuffed != null) {
      chips.add(_SurvivalChip(
        icon: Icons.restaurant,
        label: 'Hunger',
        value: gs.stuffed!,
        // Higher stuffed = more full = good (invert severity)
        severity: _invertedSeverity(gs.stuffed!),
      ));
    }
    if (gs.thirst != null) {
      chips.add(_SurvivalChip(
        icon: Icons.water_drop,
        label: 'Thirst',
        value: gs.thirst!,
        severity: _invertedSeverity(gs.thirst!),
      ));
    }
    if (gs.drunk != null && gs.drunk! > 0) {
      chips.add(_SurvivalChip(
        icon: Icons.local_bar,
        label: 'Drunk',
        value: gs.drunk!,
        severity: _severity(gs.drunk!),
      ));
    }
    if (gs.poison != null && gs.poison! > 0) {
      chips.add(_SurvivalChip(
        icon: Icons.coronavirus,
        label: 'Poison',
        value: gs.poison!,
        severity: _Severity.critical,
      ));
    }
    if (gs.encumbered != null && gs.encumbered! > 0) {
      chips.add(_SurvivalChip(
        icon: Icons.fitness_center,
        label: 'Encumbered',
        value: gs.encumbered!,
        severity: _severity(gs.encumbered!),
      ));
    }
    if (gs.med != null && gs.med! > 0) {
      chips.add(_SurvivalChip(
        icon: Icons.self_improvement,
        label: 'Bound',
        value: gs.med!,
        severity: _Severity.ok,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(230),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withAlpha(40),
          ),
        ),
      ),
      child: Row(children: chips),
    );
  }

  static _Severity _severity(int value) {
    if (value > 80) return _Severity.critical;
    if (value > 40) return _Severity.warning;
    return _Severity.ok;
  }

  /// For stats where high = good (like hunger/fullness).
  static _Severity _invertedSeverity(int value) {
    if (value < 20) return _Severity.critical;
    if (value < 50) return _Severity.warning;
    return _Severity.ok;
  }
}

enum _Severity { ok, warning, critical }

class _SurvivalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final _Severity severity;

  const _SurvivalChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      _Severity.ok => const Color(0xFF44AA44),
      _Severity.warning => const Color(0xFFCC8800),
      _Severity.critical => const Color(0xFFCC2222),
    };

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
