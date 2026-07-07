import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/ui/widgets/common/escape_dismiss.dart';
import 'package:ancient_anguish_client/ui/widgets/common/settings_drawer_route.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester, Widget pane) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => openSettingsDrawer(ctx, pane),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Widget probePane() => EscapeDismiss(
        child: Scaffold(
          appBar: AppBar(title: const Text('Probe Pane')),
          body: const Text('pane body'),
        ),
      );

  testWidgets('opens the pane docked right, leaving the scrim visible',
      (tester) async {
    await pumpHost(tester, probePane());

    expect(find.text('Probe Pane'), findsOneWidget);

    // The pane is a side panel, not fullscreen: its left edge sits well
    // inside the 800px test surface.
    final paneRect = tester.getRect(find.byType(Scaffold).last);
    expect(paneRect.right, 800);
    expect(paneRect.left, greaterThan(100));
  });

  testWidgets('back button closes the panel', (tester) async {
    await pumpHost(tester, probePane());

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Probe Pane'), findsNothing);
  });

  testWidgets('tapping the scrim closes the panel', (tester) async {
    await pumpHost(tester, probePane());

    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();
    expect(find.text('Probe Pane'), findsNothing);
  });

  testWidgets('Escape closes the panel through the pane EscapeDismiss',
      (tester) async {
    await pumpHost(tester, probePane());

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Probe Pane'), findsNothing);
  });

  testWidgets('a route pushed from inside the pane pops back to it',
      (tester) async {
    await pumpHost(
      tester,
      EscapeDismiss(
        child: Scaffold(
          appBar: AppBar(title: const Text('Probe Pane')),
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Sub Editor')),
                  ),
                ),
              ),
              child: const Text('edit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    expect(find.text('Sub Editor'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    // The panel is still open underneath.
    expect(find.text('Probe Pane'), findsOneWidget);
  });
}
