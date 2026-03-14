import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ancient_anguish_client/app.dart';
import 'package:ancient_anguish_client/providers/app_init_provider.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appInitProvider.overrideWith((ref) async {}),
        ],
        child: const AncientAnguishApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the app title is shown.
    expect(find.text('Ancient Anguish'), findsOneWidget);
  });
}
