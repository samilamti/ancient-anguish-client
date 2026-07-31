import 'package:flutter/material.dart';

import '../../../../models/sheet.dart';
import 'sheet_frame.dart';

/// Renders `score` as an expandable sheet.
///
/// Collapsed it shows only what moves while you play — Exp, Money, Hunted by and
/// the `You are:` statuses — because that is what a player types `score` for
/// mid-session. Everything else (stats, race, guild, age, combat settings) is one
/// tap away, since it changes about once a level.
///
/// The full set is always present in the model, so expanding shows the whole
/// block and nothing the MUD sent is unreachable.
class ScoreSheetWidget extends StatelessWidget {
  final ScoreSheet sheet;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const ScoreSheetWidget({
    super.key,
    required this.sheet,
    required this.expanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final frequent = sheet.frequentFields;
    final rest = sheet.restFields;

    return SheetFrame(
      icon: Icons.assignment_ind,
      title: 'Score',
      trailingLabel: expanded ? null : '${rest.length} more',
      expanded: expanded,
      onToggleExpanded: rest.isEmpty ? null : onToggleExpanded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in frequent)
            SheetRow(
              label: field.label,
              value: field.value,
              emphasised: true,
            ),
          if (sheet.statuses.isNotEmpty) ...[
            const SizedBox(height: 5),
            _Statuses(statuses: sheet.statuses),
          ],
          if (expanded) ...[
            const SizedBox(height: 8),
            _Divider(),
            const SizedBox(height: 6),
            for (final field in rest)
              SheetRow(label: field.label, value: field.value),
          ],
        ],
      ),
    );
  }
}

/// The `You are:` values as chips. They are the most volatile thing on the sheet
/// and read better as a row of states than as four rows repeating one label.
class _Statuses extends StatelessWidget {
  final List<String> statuses;

  const _Statuses({required this.statuses});

  /// Conditions worth flagging rather than merely reporting. Matched on the
  /// leading word so intensities ("Very encumbered", "Slightly hungry") are
  /// caught without listing every phrasing.
  static const Set<String> _warnWords = {
    'thirsty', 'hungry', 'starving', 'parched',
    'encumbered', 'poisoned', 'drunk', 'wounded', 'bleeding',
  };

  static bool _isWarning(String status) {
    final words = status.toLowerCase().split(RegExp(r'\s+'));
    // "Unpoisoned" is a *good* state that contains a warning word, so a plain
    // substring test would flag it — match whole words only.
    return words.any(_warnWords.contains);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: [
        for (final status in statuses)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _isWarning(status)
                  ? const Color(0xFFCC4444).withAlpha(45)
                  : scheme.onSurface.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isWarning(status)
                    ? const Color(0xFFCC4444).withAlpha(120)
                    : scheme.onSurface.withAlpha(40),
              ),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10.5,
                color: _isWarning(status)
                    ? const Color(0xFFDD7777)
                    : scheme.onSurface.withAlpha(200),
              ),
            ),
          ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(30),
      );
}
