import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ancient_anguish_client/ui/widgets/mobile/target_picker_sheet.dart';

void main() {
  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TargetPickerSheet(commandLabel: 'Kill'),
          ),
        ),
      ),
    );
  }

  group('TargetPickerSheet', () {
    testWidgets('renders the auto-identified common targets', (tester) async {
      await pumpSheet(tester);
      // First entry of kCommonTargets is always rendered at the top.
      expect(find.text('bird'), findsOneWidget);
    });

    testWidgets('typing a custom name and tapping add pins it to the top',
        (tester) async {
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField), 'balrog');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // The pinned entry is shown, distinct with a pin icon and an unpin
      // (close) button.
      expect(find.text('balrog'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // The filter field is cleared after adding.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '');
    });

    testWidgets('normalizes a custom name to a lower-case keyword',
        (tester) async {
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField), '  Ancient   Dragon ');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('ancient dragon'), findsOneWidget);
    });

    testWidgets('tapping the unpin button removes the pinned target',
        (tester) async {
      await pumpSheet(tester);

      await tester.enterText(find.byType(TextField), 'balrog');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.push_pin), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // No longer pinned, and "balrog" isn't an auto target so it's gone.
      expect(find.byIcon(Icons.push_pin), findsNothing);
      expect(find.text('balrog'), findsNothing);
    });
  });
}
