import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/game_state_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';
import 'package:ancient_anguish_client/ui/widgets/compass/compass_overlay.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        promptParserProvider.overrideWithValue(PromptParser()),
        areaDetectorProvider
            .overrideWith((ref) => Future.value(AreaDetector())),
        unifiedAreaConfigProvider
            .overrideWith((ref) => Future.value(UnifiedAreaConfigManager())),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpOverlay(WidgetTester tester) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: CompassOverlay())),
        ),
      ),
    );
  }

  void moveTo(int x, int y) => container
      .read(gameStateProvider.notifier)
      .updateVitalsAndCoordinates(100, 100, 50, 50, x, y);

  Finder roseFinder() => find.descendant(
        of: find.byType(CompassOverlay),
        matching: find.byType(CustomPaint),
      );

  testWidgets('renders nothing while coordinates are unknown',
      (tester) async {
    await pumpOverlay(tester);
    expect(roseFinder(), findsNothing);
    expect(find.textContaining('Tantallon'), findsNothing);
  });

  testWidgets('shows nearby location labels once coordinates arrive',
      (tester) async {
    await pumpOverlay(tester);
    moveTo(11, 42); // Standing in Norton.
    await tester.pump();

    expect(find.text('Norton · here'), findsOneWidget); // Nearest chip.
    expect(find.text('Norton'), findsOneWidget); // Marker label.
    expect(find.text('Sands bridge'), findsOneWidget); // Neighbor at ~1.4.
    expect(roseFinder(), findsOneWidget);
  });

  testWidgets('shows a bare rose with no chip when nothing is nearby',
      (tester) async {
    await pumpOverlay(tester);
    moveTo(35, 15); // Middle of the ocean.
    await tester.pump();

    expect(roseFinder(), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('hides again when coordinates reset on disconnect',
      (tester) async {
    await pumpOverlay(tester);
    moveTo(0, 0);
    await tester.pump();
    expect(find.textContaining('Tantallon'), findsWidgets);

    container.read(gameStateProvider.notifier).reset();
    await tester.pump();
    expect(roseFinder(), findsNothing);
  });
}
