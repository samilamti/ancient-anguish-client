import 'package:ancient_anguish_client/ui/widgets/social/panel_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, double width) async {
    void noop() {}
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: PanelTitleBar(
              title: 'Chat',
              isDocked: true,
              isTabbed: true,
              onClose: noop,
              onUndock: noop,
              onSeparateTabs: noop,
              onCycleTimestampMode: noop,
              timestampModeIcon: Icons.schedule,
              timestampModeLabel: 'Hover',
              onPanStart: (_) {},
              onPanUpdate: (_) {},
              onPanEnd: (_) {},
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('a wide bar labels its pills', (tester) async {
    await pumpBar(tester, 500);
    expect(tester.takeException(), isNull);
    expect(find.text('Undock'), findsOneWidget);
    expect(find.text('Separate'), findsOneWidget);
  });

  testWidgets('a narrow bar drops the labels instead of overflowing',
      (tester) async {
    await pumpBar(tester, 240);
    expect(tester.takeException(), isNull);
    expect(find.text('Undock'), findsNothing);
    expect(find.byTooltip('Undock'), findsOneWidget);
    expect(find.byTooltip('Separate'), findsOneWidget);
  });
}
