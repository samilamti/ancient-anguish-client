import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/line_spacing.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';

import 'terminal_view_helpers.dart';

/// The terminal converts a pointer offset into a buffer line by dividing by a
/// single measured line height, so extra line spacing has to reach that maths
/// as well as the rendering. When the two disagree, selection and link
/// hit-testing drift by a line per row — silently, and worse the further up the
/// viewport you click.
void main() {
  /// Eight rows above the newest line: far enough up that a per-row drift
  /// exceeds half a line height and lands the selection on the wrong line,
  /// close enough to the bottom to stay on screen at every spacing step.
  const targetText = 'Line 22';

  Future<void> expectHitTestAgreesWithPaint(
    WidgetTester tester,
    LineSpacing spacing,
  ) async {
    // Distinct per line, so a copy that lands one row off is unmistakable.
    final lines = createStyledLines(
      List.generate(30, (i) => 'Line ${i.toString().padLeft(2, '0')}'),
    );
    final container = await pumpTerminalView(tester, lines: lines);
    final clipboard = setupClipboardMock(tester);

    container.read(settingsProvider.notifier).setLineSpacing(spacing);
    await tester.pumpAndSettle();

    // Where the target line is actually *painted*.
    final painted = tester.getRect(findRichTextContaining(targetText));
    final listRect = tester.getRect(find.byType(ListView));

    // Start near the left edge so anchor and focus land on different columns —
    // a center-x drag clamps short lines to a single column.
    await tester.dragFrom(
      Offset(listRect.left + 12, painted.center.dy),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(
      clipboard(),
      targetText,
      reason: 'selection landed on the wrong line at ${spacing.label} spacing',
    );
  }

  for (final spacing in LineSpacing.values) {
    testWidgets('drag-select hits the painted line at ${spacing.label} spacing',
        (tester) async {
      await expectHitTestAgreesWithPaint(tester, spacing);
    });
  }
}
