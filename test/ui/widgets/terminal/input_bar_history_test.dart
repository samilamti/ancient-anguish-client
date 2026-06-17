import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ancient_anguish_client/providers/connection_provider.dart'
    show commandHistoryProvider;
import 'package:ancient_anguish_client/ui/widgets/terminal/input_bar.dart';

void main() {
  // Pumps the InputBar at [size] and returns the enclosing ProviderContainer
  // so the test can seed command history before opening the sheet.
  Future<ProviderContainer> pumpInputBar(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: InputBar()),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(InputBar)));
  }

  group('InputBar recent-commands sheet', () {
    testWidgets('desktop lists more recent commands than mobile', (
      tester,
    ) async {
      final container = await pumpInputBar(
        tester,
        size: const Size(1200, 1000),
      );
      // Seed 10 single-word commands (none produce counterparts).
      final history = container.read(commandHistoryProvider.notifier);
      for (var i = 0; i < 10; i++) {
        history.add('foo$i');
      }
      await tester.pump();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // Desktop cap is 20, so all 10 are visible — including the oldest.
      expect(find.text('foo0'), findsOneWidget);
      expect(find.text('foo9'), findsOneWidget);
    });

    testWidgets('mobile caps the recent list at 8', (tester) async {
      final container = await pumpInputBar(
        tester,
        size: const Size(400, 800),
      );
      final history = container.read(commandHistoryProvider.notifier);
      for (var i = 0; i < 10; i++) {
        history.add('foo$i');
      }
      await tester.pump();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // Newest 8 (foo9..foo2) show; the two oldest are dropped.
      expect(find.text('foo9'), findsOneWidget);
      expect(find.text('foo2'), findsOneWidget);
      expect(find.text('foo1'), findsNothing);
      expect(find.text('foo0'), findsNothing);
    });

    testWidgets('"+" on a recent command opens the alias editor with the '
        'expansion pre-filled', (tester) async {
      final container = await pumpInputBar(
        tester,
        size: const Size(1200, 1000),
      );
      container.read(commandHistoryProvider.notifier).add('cast fireball');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      expect(find.text('cast fireball'), findsOneWidget);

      // The row's "+" button creates an alias from that command.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // We land on the New Alias editor with the expansion pre-filled and the
      // keyword left empty for the user to name.
      expect(find.text('New Alias'), findsOneWidget);
      final expansionField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'cast fireball'),
      );
      expect(expansionField.controller!.text, 'cast fireball');
    });

    testWidgets('counterpart rows show a ↳ and no "+" alias button', (
      tester,
    ) async {
      final container = await pumpInputBar(
        tester,
        size: const Size(1200, 1000),
      );
      // "enter" has a counterpart ("leave"), so the sheet shows one recent row
      // and one counterpart row.
      container.read(commandHistoryProvider.notifier).add('enter');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('enter'), findsOneWidget); // recent
      expect(find.text('leave'), findsOneWidget); // derived counterpart

      // Only the recent row carries a "+"; the counterpart carries the ↳.
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.subdirectory_arrow_right), findsOneWidget);
    });
  });
}
