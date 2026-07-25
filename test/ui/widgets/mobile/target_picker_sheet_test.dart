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

      // The pinned entry is shown, marked by the leading pin icon.
      expect(find.text('balrog'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin), findsOneWidget);

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

    testWidgets('tapping the pin icon unpins instead of choosing the target',
        (tester) async {
      final picked = await _pumpPickerAndPin(tester, tapPin: true);

      // Unpinned rather than picked: "balrog" isn't an auto target, so it
      // leaves the list, and the sheet stays open with no result returned.
      expect(find.byIcon(Icons.push_pin), findsNothing);
      expect(find.text('balrog'), findsNothing);
      expect(picked(), isNull);
    });

    testWidgets('tapping the row body still chooses the pinned target',
        (tester) async {
      final picked = await _pumpPickerAndPin(tester, tapPin: false);

      // The label sits outside the pin's hit box, so it keeps the choose
      // action and pops the sheet with the target.
      expect(picked(), 'balrog');
    });
  });
}

/// Opens the real `TargetPickerSheet.show` flow, pins "balrog", then taps
/// either its pin icon or its label. Returns a getter for whatever the sheet
/// resolved with (`null` while it's still open).
Future<String? Function()> _pumpPickerAndPin(
  WidgetTester tester, {
  required bool tapPin,
}) async {
  String? result;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await TargetPickerSheet.show(ctx, commandLabel: 'Kill');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), 'balrog');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.push_pin), findsOneWidget);

  await tester.tap(
    tapPin ? find.byIcon(Icons.push_pin) : find.text('balrog'),
  );
  await tester.pumpAndSettle();

  return () => result;
}
