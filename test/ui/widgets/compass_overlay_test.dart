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

  // Standing in a town, half a dozen gazetteer entries land within a stadion or
  // two of each other while a label box is many times wider than the gap
  // between their plotted points. Drawn at their true positions the names pile
  // into an unreadable smudge, so the rose slides them apart.
  group('label de-collision', () {
    /// Every marker name currently on the rose, with the box it occupies.
    ///
    /// Read from the rendered widgets rather than predicted, so this also
    /// catches the de-collision pass measuring labels differently from the way
    /// they actually lay out.
    Map<String, Rect> labelBoxes(WidgetTester tester, List<String> names) {
      final boxes = <String, Rect>{};
      for (final name in names) {
        final finder = find.text(name);
        if (finder.evaluate().isNotEmpty) {
          boxes[name] = tester.getRect(finder.first);
        }
      }
      return boxes;
    }

    /// Names of the locations the rose is willing to label at [maxLabeled].
    List<String> candidates(int maxLabeled) => container
        .read(nearbyLocationsProvider)
        .take(maxLabeled)
        .map((e) => e.location.shortName)
        .toList();

    void expectNoOverlaps(Map<String, Rect> boxes) {
      final names = boxes.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          final a = boxes[names[i]]!, b = boxes[names[j]]!;
          expect(a.overlaps(b), isFalse,
              reason: '"${names[i]}" $a overlaps "${names[j]}" $b');
        }
      }
    }

    Future<void> pumpRose(WidgetTester tester, double size,
        int maxLabeled) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      moveTo(0, 0); // Tantallon: the densest spot on the map.

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: CompassRose(size: size, maxLabeledMarkers: maxLabeled),
              ),
            ),
          ),
        ),
      );
    }

    // Both the desktop diameter and the phone-sized one the strip opens: the
    // crowding is not caused by the smaller size, it is only worse there.
    for (final (size, maxLabeled) in [(kCompassSize, 6), (343.0, 4)]) {
      testWidgets('no two labels overlap at $size', (tester) async {
        await pumpRose(tester, size, maxLabeled);

        final boxes = labelBoxes(tester, candidates(maxLabeled));
        expect(boxes, isNotEmpty);
        expectNoOverlaps(boxes);
        expect(tester.takeException(), isNull);
      });

      testWidgets('every nearby location is still marked at $size',
          (tester) async {
        // A name may be dropped when nothing fits, but the icon must stay so
        // the place is not silently erased from the rose.
        await pumpRose(tester, size, maxLabeled);
        expect(find.byType(Image), findsNWidgets(maxLabeled));
      });
    }

    testWidgets('keeps the nearest location at its true plotted point',
        (tester) async {
      // De-collision runs nearest-first, so the most relevant marker never
      // moves — only the ones behind it in the queue give ground.
      await pumpRose(tester, kCompassSize, 6);

      final nearest = container.read(nearbyLocationsProvider).first;
      final disc = tester.getRect(find
          .descendant(
            of: find.byType(CompassRose),
            matching: find.byType(CustomPaint),
          )
          .first);
      final label = tester.getRect(find.text(nearest.location.shortName).first);

      // Standing on Tantallon, it plots at the minimum radius due north.
      expect(label.center.dx, closeTo(disc.center.dx, 0.5));
      expect(label.center.dy, lessThan(disc.center.dy));
    });

    testWidgets('leaves labels alone where nothing is crowded',
        (tester) async {
      // Out in open country the plotted point is the honest position and must
      // be used as-is; de-collision is only allowed to act on a real collision.
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      moveTo(-21, -28); // Empty country: only Silent grove is in range.

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Center(child: CompassRose())),
          ),
        ),
      );

      final nearby = container.read(nearbyLocationsProvider);
      expect(nearby, hasLength(1));

      final disc = tester.getRect(find
          .descendant(
            of: find.byType(CompassRose),
            matching: find.byType(CustomPaint),
          )
          .first);
      final label = tester.getRect(find.text(nearby.first.location.shortName));
      // Untouched means still centred on its own bearing line.
      final expected = disc.center.dx +
          math.sin(nearby.first.bearing) *
              (32 + (nearby.first.distance / kCompassRangeStadia) * 120);
      expect(label.center.dx, closeTo(expected, 0.5));
    });
  });

  // The phone gets the same overlay in the same top-right corner as desktop —
  // just the small presentation of the rose, since the 432px disc is wider than
  // the screen.
  group('compact presentation', () {
    const phone = Size(390, 800);

    Future<void> pumpCompact(WidgetTester tester) async {
      tester.view.physicalSize = phone * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: Colors.black)),
                  Positioned(
                    top: 8,
                    right: 12,
                    child: CompassOverlay(compact: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('fits the phone and sits in the top-right corner',
        (tester) async {
      await pumpCompact(tester);
      moveTo(0, 0); // Tantallon.
      await tester.pump();

      final disc = tester.getRect(roseFinder().first);
      expect(disc.width, phoneCompassSize(const MediaQueryData(size: phone)));
      expect(disc.width, lessThan(phone.width));

      // Hard against the top-right, where the desktop rose floats. The disc
      // itself, not just the overlay box: with the nearest-location chip under
      // it the rose was wider than the disc and the disc came out mid-screen.
      expect(disc.right, closeTo(phone.width - 12, 0.5));
      expect(disc.top, closeTo(8, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('carries no text at all, so it stays a disc in the corner',
        (tester) async {
      await pumpCompact(tester);
      moveTo(11, 42); // Standing in Norton.
      await tester.pump();

      // No marker labels and no cardinal letters at half diameter, and no
      // nearest-location chip either — [CompassStrip] names the place, and the
      // chip is wide enough to drag the disc off the corner.
      expect(find.text('Norton'), findsNothing);
      expect(find.text('Sands bridge'), findsNothing);
      expect(find.text('N'), findsNothing);
      expect(find.text('Norton · here'), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows at most one marker per direction', (tester) async {
      await pumpCompact(tester);
      moveTo(0, 0); // Tantallon: the densest spot on the map.
      await tester.pump();

      final directions = container
          .read(nearbyLocationsProvider)
          .map((e) => e.direction)
          .toSet();
      expect(find.byType(Image), findsNWidgets(directions.length));
    });

    testWidgets('lets terminal taps through to the output underneath',
        (tester) async {
      await pumpCompact(tester);
      moveTo(0, 0);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(CompassOverlay),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });
  });
}
