import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/compass_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';
import 'package:ancient_anguish_client/ui/widgets/compass/compass_overlay.dart';
import 'package:ancient_anguish_client/ui/widgets/compass/compass_strip.dart';

/// The compass on mobile: a one-line readout that costs almost no height, and
/// opens the full rose on tap. The rose itself is 432px — wider than a phone —
/// so the strip is the only thing that can be always-on there.
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
    addTearDown(container.dispose);
  });

  /// Drives the player's position, which is what the compass derives from.
  /// (0,0) is Tantallon itself; the tests otherwise read expectations back from
  /// `nearbyLocationsProvider` rather than assuming which place is nearest —
  /// the gazetteer is dense enough that a coordinate's nearest location is not
  /// obvious from the map.
  void moveTo(int x, int y) => container
      .read(gameStateProvider.notifier)
      .updateVitalsAndCoordinates(100, 100, 50, 50, x, y);

  Future<void> pumpStrip(WidgetTester tester,
      {Size size = const Size(375, 812)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CompassStrip(),
                Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  group('CompassStrip', () {
    testWidgets('costs no height while coordinates are unknown',
        (tester) async {
      await pumpStrip(tester);
      expect(tester.getSize(find.byType(CompassStrip)).height, 0);
    });

    testWidgets('costs no height out at sea, where nothing is in range',
        (tester) async {
      moveTo(35, 15);
      await pumpStrip(tester);
      expect(tester.getSize(find.byType(CompassStrip)).height, 0);
    });

    testWidgets('names the nearest location with its distance', (tester) async {
      moveTo(0, -3);
      await pumpStrip(tester);

      // Asserted against the provider rather than a hardcoded place name: the
      // contract is "the strip shows what the compass computed", and which
      // location happens to be nearest to a coordinate is gazetteer data.
      final nearest = container.read(nearbyLocationsProvider).first;
      expect(find.text(nearest.location.shortName), findsOneWidget);
      expect(
        find.text('${nearest.distance.round()} st ${nearest.direction}'),
        findsOneWidget,
      );
    });

    testWidgets('reads "here" when standing on the location', (tester) async {
      moveTo(0, 0);
      await pumpStrip(tester);
      expect(find.text('here'), findsOneWidget);
    });

    testWidgets('stays a thin strip on a phone', (tester) async {
      // The whole point of the option: an always-on rose would take about a
      // third of the usable height, so this must stay in status-bar territory.
      moveTo(0, -3);
      await pumpStrip(tester);

      final height = tester.getSize(find.byType(CompassStrip)).height;
      expect(height, greaterThan(0));
      expect(height, lessThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bearing arrow is rotated to the true bearing',
        (tester) async {
      // Icons.navigation already points north, so the applied rotation should
      // be exactly the bearing — that is what makes the arrow readable without
      // parsing "NE".
      double arrowAngle() {
        final m = tester
            .widget<Transform>(find.ancestor(
              of: find.byIcon(Icons.navigation),
              matching: find.byType(Transform),
            ))
            .transform;
        return math.atan2(m.storage[1], m.storage[0]);
      }

      double expectedAngle() {
        final bearing = container.read(nearbyLocationsProvider).first.bearing;
        // atan2 reports in (-pi, pi]; bearings run 0..2pi.
        return bearing > math.pi ? bearing - 2 * math.pi : bearing;
      }

      for (final position in [(0, -3), (-3, 0), (2, 2)]) {
        moveTo(position.$1, position.$2);
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpStrip(tester);
        expect(arrowAngle(), closeTo(expectedAngle(), 0.0001),
            reason: 'at $position');
      }
    });

    testWidgets('tapping opens the full rose, and tapping it dismisses',
        (tester) async {
      moveTo(0, -3);
      await pumpStrip(tester);

      expect(find.byType(CompassRose), findsNothing);

      await tester.tap(find.byType(CompassStrip));
      await tester.pumpAndSettle();
      expect(find.byType(CompassRose), findsOneWidget);

      await tester.tap(find.byType(CompassRose));
      await tester.pumpAndSettle();
      expect(find.byType(CompassRose), findsNothing);
    });

    testWidgets('the opened rose fits inside a phone screen', (tester) async {
      moveTo(0, -3);
      await pumpStrip(tester);
      await tester.tap(find.byType(CompassStrip));
      await tester.pumpAndSettle();

      final rose = tester.getRect(find.byType(CompassRose));
      expect(rose.width, lessThanOrEqualTo(375));
      expect(rose.height, lessThanOrEqualTo(812));
      // Genuinely smaller than the desktop disc, i.e. it really did scale.
      expect(rose.width, lessThan(kCompassSize));
      expect(tester.takeException(), isNull);
    });
  });

  group('CompassRose scaling', () {
    /// The disc itself. [CompassRose] is a Column whose nearest-location chip
    /// is wider than the disc, so measuring the widget measures the chip.
    Rect disc(WidgetTester tester) => tester.getRect(find
        .descendant(
          of: find.byType(CompassRose),
          matching: find.byType(CustomPaint),
        )
        .first);

    Future<Rect> pumpRose(WidgetTester tester, double size) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      moveTo(0, -3);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: Center(child: CompassRose(size: size))),
          ),
        ),
      );
      return disc(tester);
    }

    testWidgets('defaults to the desktop diameter', (tester) async {
      final rect = await pumpRose(tester, kCompassSize);
      expect(rect.width, kCompassSize);
    });

    testWidgets('renders at a phone-sized diameter without overflowing',
        (tester) async {
      final rect = await pumpRose(tester, 240);
      expect(rect.width, 240);
      expect(tester.takeException(), isNull);
    });

    testWidgets('marker labels keep their font size when the disc shrinks',
        (tester) async {
      // Scaling the label text is what makes a shrunken compass useless, so
      // only the geometry scales.
      await pumpRose(tester, 240);
      final label = tester.widget<Text>(find.text('Tantallon'));
      expect(label.style?.fontSize, 12);
    });
  });
}
