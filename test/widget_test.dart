import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ancient_anguish_client/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AncientAnguishApp()),
    );

    // Verify the app title is shown.
    expect(find.text('Ancient Anguish'), findsOneWidget);
  });
}
