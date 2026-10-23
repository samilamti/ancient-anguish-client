import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ancient_anguish_client/providers/connection_provider.dart'
    show commandHistoryProvider;
import 'package:ancient_anguish_client/providers/local_features_provider.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/input_bar.dart';

void main() {
  // Pumps the InputBar at [size] and returns the enclosing ProviderContainer
  // so the test can seed command history before opening the sheet.
  Future<ProviderContainer> pumpInputBar(
    WidgetTester tester, {
    required Size size,
    bool localFeatures = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localFeaturesAvailableProvider
              .overrideWith((ref) async => localFeatures),
        ],
        child: const MaterialApp(
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

    testWidgets('mobile caps the recent list at 16', (tester) async {
      final container = await pumpInputBar(
        tester,
        size: const Size(400, 800),
      );
      final history = container.read(commandHistoryProvider.notifier);
      // 18 commands — two more than the mobile cap, and less than the 20
      // the history service retains, so the cap is what does the trimming.
      for (var i = 0; i < 18; i++) {
        history.add('foo$i');
      }
      await tester.pump();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // Newest first, and the two oldest are dropped by the 16 cap.
      expect(find.text('foo17'), findsOneWidget);
      expect(find.text('foo1'), findsNothing);
      expect(find.text('foo0'), findsNothing);

      // The 16th entry sits past the sheet's height — reachable only by
      // scrolling, which is the point of the taller list.
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('foo2'), findsOneWidget);
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

      // Only the recent row carries a "+"; the counterparts carry the ↳.
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.subdirectory_arrow_right), findsNWidgets(2));
    });

    testWidgets('long-press offers rules that send the command', (
      tester,
    ) async {
      final container = await pumpInputBar(
        tester,
        size: const Size(1200, 1000),
      );
      container.read(commandHistoryProvider.notifier).add('stand');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('stand'));
      await tester.pumpAndSettle();

      expect(find.text('Create alias…'), findsOneWidget);
      expect(find.text('Create trigger…'), findsNothing,
          reason: 'triggers are local-only');
      await tester.tap(find.text('Create text link rule…'));
      await tester.pumpAndSettle();

      // The existing editor, with the command pre-filled and the pattern
      // left for the user.
      final command = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Command template'));
      expect(command.controller!.text, 'stand');
      final pattern = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Pattern (regex)'));
      expect(pattern.controller!.text, isEmpty);
    });

    testWidgets('long-press "Create trigger…" in local builds pre-fills the '
        'command', (tester) async {
      final container = await pumpInputBar(
        tester,
        size: const Size(1200, 1000),
        localFeatures: true,
      );
      container.read(commandHistoryProvider.notifier).add('enter');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      // A counterpart row: no alias option, but rules are fine.
      await tester.longPress(find.text('leave'));
      await tester.pumpAndSettle();
      expect(find.text('Create alias…'), findsNothing);
      await tester.tap(find.text('Create trigger…'));
      await tester.pumpAndSettle();

      final command = tester.widget<TextField>(
          find.widgetWithText(TextField, 'Command template'));
      expect(command.controller!.text, 'leave');
    });

    testWidgets('Counterparts section renders above Recent', (tester) async {
      final container = await pumpInputBar(
        tester,
        size: const Size(1200, 1000),
      );
      container.read(commandHistoryProvider.notifier).add('enter');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      final counterpartsY = tester.getTopLeft(find.text('Counterparts')).dy;
      final recentY = tester.getTopLeft(find.text('Recent')).dy;
      expect(counterpartsY, lessThan(recentY));
    });

    testWidgets('re-running a command moves it back to the top of history',
        (tester) async {
      final container = await pumpInputBar(
        tester,
        size: const Size(1200, 1000),
      );
      final history = container.read(commandHistoryProvider.notifier);
      history.add('cast fireball');
      history.add('wield sword');
      history.add('drink potion');
      expect(container.read(commandHistoryProvider),
          ['drink potion', 'wield sword', 'cast fireball']);

      // Re-running the oldest entry refreshes its recency rather than
      // leaving a stale duplicate behind.
      history.add('cast fireball');
      expect(container.read(commandHistoryProvider),
          ['cast fireball', 'drink potion', 'wield sword']);
    });
  });
}
