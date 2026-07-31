import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/sheet.dart';
import '../../../../providers/sheet_provider.dart';
import 'score_sheet_widget.dart';
import 'shop_list_sheet_widget.dart';
import 'skills_sheet_widget.dart';

/// Looks up the sheet a sentinel line refers to and renders it.
///
/// One dispatch point, so `TerminalLine` stays a two-line hook and adding a
/// fourth sheet kind means a parser, a widget and one `case` here — not another
/// provider lookup and Consumer in the line renderer.
///
/// Renders nothing when the id is unknown, which happens after the buffer is
/// cleared: the sentinel line can outlive its sheet, and a blank is a better
/// answer there than an error.
class SheetWidget extends ConsumerWidget {
  final int sheetId;

  const SheetWidget({super.key, required this.sheetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(sheetsProvider)[sheetId];
    if (sheet == null) return const SizedBox.shrink();

    switch (sheet) {
      case SkillsSheet():
        return SkillsSheetWidget(sheet: sheet);
      case ScoreSheet():
        final expanded =
            ref.watch(expandedSheetsProvider).contains(sheetId);
        return ScoreSheetWidget(
          sheet: sheet,
          expanded: expanded,
          onToggleExpanded: () =>
              ref.read(expandedSheetsProvider.notifier).toggle(sheetId),
        );
      case ShopListSheet():
        final byCost =
            ref.watch(costSortedSheetsProvider).contains(sheetId);
        return ShopListSheetWidget(
          sheet: sheet,
          sortedByCost: byCost,
          onToggleSort: () =>
              ref.read(costSortedSheetsProvider.notifier).toggle(sheetId),
        );
    }
  }
}
