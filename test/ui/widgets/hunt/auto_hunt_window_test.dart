import 'package:ancient_anguish_client/providers/auto_hunt_provider.dart';
import 'package:ancient_anguish_client/providers/local_features_provider.dart';
import 'package:ancient_anguish_client/ui/widgets/hunt/auto_hunt_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester, {bool local = true}) async {
    final container = ProviderContainer(overrides: [
      localFeaturesAvailableProvider.overrideWith((ref) async => local),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: Stack(children: [
          Positioned.fill(child: AutoHuntWindowOverlay()),
        ])),
      ),
    ));
    await tester.pump();
    return container;
  }

  testWidgets('hidden until opened, then shows the lists', (tester) async {
    final c = await pump(tester);
    expect(find.text('Auto Hunt'), findsNothing);

    c.read(autoHuntWindowProvider.notifier).open();
    await tester.pump();
    expect(find.text('Auto Hunt'), findsOneWidget);
    expect(find.text('Targets'), findsOneWidget);
    expect(find.text('hill giant'), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
  });

  testWidgets('never shows without the local features marker', (tester) async {
    final c = await pump(tester, local: false);
    c.read(autoHuntWindowProvider.notifier).open();
    await tester.pump();
    expect(find.text('Auto Hunt'), findsNothing);
  });

  testWidgets('drags by its title bar and closes', (tester) async {
    final c = await pump(tester);
    c.read(autoHuntWindowProvider.notifier).open();
    await tester.pump();
    final before = c.read(autoHuntWindowProvider).position;
    await tester.drag(find.text('Auto Hunt'), const Offset(40, 30));
    await tester.pump();
    expect(c.read(autoHuntWindowProvider).position, before + const Offset(40, 30));

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.text('Auto Hunt'), findsNothing);
  });
}
