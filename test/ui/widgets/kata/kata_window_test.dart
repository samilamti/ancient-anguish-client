import 'package:ancient_anguish_client/providers/kata_provider.dart';
import 'package:ancient_anguish_client/providers/local_features_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/ui/widgets/kata/kata_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester, {bool local = true}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      localFeaturesAvailableProvider.overrideWith((ref) async => local),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: Stack(children: [
          Positioned.fill(child: KataWindowOverlay()),
        ])),
      ),
    ));
    await tester.pump();
    return container;
  }

  testWidgets('shows ten slots and saves what is typed', (tester) async {
    final c = await pump(tester);
    expect(find.text('Katas'), findsNothing);
    c.read(kataWindowProvider.notifier).open();
    await tester.pump();
    expect(find.text('Katas'), findsOneWidget);
    expect(find.text('1s'), findsOneWidget);
    expect(find.text('10s'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('kata-slot-2')), 'kick');
    expect(c.read(settingsProvider).kataSlots[1], 'kick');
  });

  testWidgets('switch arms the Kata once a slot is filled', (tester) async {
    final c = await pump(tester);
    c.read(kataWindowProvider.notifier).open();
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('kata-slot-1')), 'kick');
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(c.read(kataProvider).armed, isTrue);
    expect(find.text('Waiting for a fight'), findsOneWidget);
  });

  testWidgets('never shows without the local features marker', (tester) async {
    final c = await pump(tester, local: false);
    c.read(kataWindowProvider.notifier).open();
    await tester.pump();
    expect(find.text('Katas'), findsNothing);
  });
}
