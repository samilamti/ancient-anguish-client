import 'package:flutter/material.dart';

/// An animated gauge bar for displaying a value as a fraction (e.g., HP, SP).
///
/// Renders as a horizontal bar with a gradient fill, label, and numeric value.
/// Animates smoothly when the value changes.
class VitalsGauge extends StatelessWidget {
  /// The label text (e.g., "HP", "SP").
  final String label;

  /// Current value (e.g., current HP).
  final int value;

  /// Maximum value (e.g., max HP).
  final int maxValue;

  /// The gradient colors for the fill bar.
  final List<Color> gradientColors;

  /// The icon to show before the label.
  final IconData? icon;

  const VitalsGauge({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    required this.gradientColors,
    this.icon,
  });

  double get _fraction =>
      maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label row.
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: gradientColors.last),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: theme.colorScheme.onSurface.withAlpha(180),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '$value / $maxValue',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: theme.colorScheme.onSurface.withAlpha(200),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),

        // Gauge bar.
        SizedBox(
          height: 14,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Background track.
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: gradientColors.last.withAlpha(40),
                      width: 1,
                    ),
                  ),
                ),

                // Animated fill.
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  widthFactor: _fraction,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors.last.withAlpha(60),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A [FractionallySizedBox] that smoothly animates width changes.
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final AlignmentGeometry alignment;
  final Widget child;

  const AnimatedFractionallySizedBox({
    super.key,
    required super.duration,
    super.curve,
    required this.widthFactor,
    required this.alignment,
    required this.child,
  });

  @override
  AnimatedWidgetBaseState<AnimatedFractionallySizedBox> createState() =>
      _AnimatedFractionallySizedBoxState();
}

class _AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      alignment: widget.alignment,
      child: widget.child,
    );
  }
}
