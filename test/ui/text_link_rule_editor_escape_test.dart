import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ancient_anguish_client/ui/screens/text_link_rules_screen.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => openTextLinkRuleEditor(
                  ctx,
                  initialMatchText: 'You must be standing.',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('New Text Link Rule'), findsOneWidget);
  }

  testWidgets('Escape closes the New Text Link Rule editor', (tester) async {
    await pumpEditor(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('New Text Link Rule'), findsNothing);
  });

  testWidgets('Escape closes the editor even while a field is focused',
      (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.widgetWithText(TextField, 'Name'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('New Text Link Rule'), findsNothing);
  });
}
