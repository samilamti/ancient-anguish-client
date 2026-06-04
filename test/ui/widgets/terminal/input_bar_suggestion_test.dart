import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ancient_anguish_client/ui/widgets/terminal/input_bar.dart';

void main() {
  Future<void> pumpInputBar(WidgetTester tester, {required Size size}) async {
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
  }

  group('InputBar mobile auto-completion', () {
    testWidgets('suggestion chip appears for a matching trigger and fills '
        'the completion on tap', (tester) async {
      await pumpInputBar(tester, size: const Size(400, 800));

      await tester.enterText(find.byType(TextField), 'dot');
      await tester.pump();

      // The chip shows the completion (trailing space trimmed for display).
      expect(find.text('dotimes 30'), findsOneWidget);

      await tester.tap(find.text('dotimes 30'));
      await tester.pump();

      // The full completion — including the trailing space — fills the input.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'dotimes 30 ');

      // Once typed past the trigger, the suggestion clears.
      expect(find.text('dotimes 30'), findsNothing);
    });

    testWidgets('no suggestion chip on desktop widths', (tester) async {
      await pumpInputBar(tester, size: const Size(1200, 800));

      await tester.enterText(find.byType(TextField), 'dot');
      await tester.pump();

      expect(find.text('dotimes 30'), findsNothing);
    });
  });
}
