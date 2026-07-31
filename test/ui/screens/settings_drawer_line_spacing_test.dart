import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/line_spacing.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/ui/screens/home_screen.dart';

/// The settings drawer is the only settings surface on every platform
/// (`settings_screen.dart` is orphaned), so a control added there has to be
/// reachable and usable at phone width too — not just on a 480px desktop panel.
void main() {
  Future<ProviderContainer> pumpDrawer(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            endDrawer: SettingsDrawer(isMobile: size.width < 768),
          ),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold)).openEndDrawer();
    await tester.pumpAndSettle();
    return container;
  }

  for (final (label, size) in [
    ('phone', const Size(375, 812)),
    ('desktop', const Size(1280, 800)),
  ]) {
    testWidgets('Line Spacing is present and adjustable on $label',
        (tester) async {
      final container = await pumpDrawer(tester, size: size);

      await tester.scrollUntilVisible(find.text('Line Spacing'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      expect(find.text('Line Spacing'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Identified by its range rather than by position, so reordering the
      // drawer can't quietly retarget this at the font-size slider.
      final spacingSlider = tester
          .widgetList<Slider>(find.byType(Slider))
          .where((s) => s.max == (LineSpacing.values.length - 1).toDouble());
      expect(spacingSlider, hasLength(1),
          reason: 'exactly one slider should be the line-spacing one');
      expect(spacingSlider.single.value, 0, reason: 'defaults to off');

      spacingSlider.single.onChanged!(2);
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).lineSpacing, LineSpacing.third);
      expect(find.text('33%'), findsOneWidget);
    });
  }
}
