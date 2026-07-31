import 'package:flutter/material.dart';

import '../../../../models/sheet.dart';
import 'sheet_frame.dart';

/// Renders `skills` as a bar chart.
///
/// The MUD's two-column fixed-width table answers "what is my Knife rating" but
/// makes "where am I strong" a reading exercise. Bars scaled to the player's own
/// best skill answer that at a glance, and the number stays alongside so nothing
/// the text gave you is lost.
///
/// Wraps into as many columns as fit, so this is one column on a phone and two
/// or three on a desktop panel — the MUD's layout was two columns because 80
/// characters is two columns wide, which is not a reason that applies here.
class SkillsSheetWidget extends StatelessWidget {
  final SkillsSheet sheet;

  const SkillsSheetWidget({super.key, required this.sheet});

  /// Roughly the narrowest a name + bar + number stays readable at.
  static const double _minColumnWidth = 190;

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      icon: Icons.fitness_center,
      title: 'Weapon skills',
      trailingLabel: '${sheet.skills.length} skills · best ${sheet.maxValue}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth.isFinite
              ? (constraints.maxWidth / _minColumnWidth).floor().clamp(1, 4)
              : 1;
          final rows = (sheet.skills.length / columns).ceil();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: c == columns - 1 ? 0 : 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var r = 0; r < rows; r++)
                          if (c * rows + r < sheet.skills.length)
                            _SkillBar(
                              skill: sheet.skills[c * rows + r],
                              maxValue: sheet.maxValue,
                            ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  final SkillEntry skill;
  final int maxValue;

  const _SkillBar({required this.skill, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = (skill.value / maxValue).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Track, then fill: the bar is drawn behind the name so a long
                // skill name never squeezes the bar to nothing.
                Container(
                  height: 15,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withAlpha(20),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 15,
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(70),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        skill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10.5,
                          color: scheme.onSurface.withAlpha(230),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '${skill.value}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
