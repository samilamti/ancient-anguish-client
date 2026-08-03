import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/notification_provider.dart';
import 'package:ancient_anguish_client/ui/widgets/common/notification_overlay.dart';

/// Notifications used to be bottom-anchored SnackBars, which covered the input
/// bar and the newest output lines — and one carrying an action would sit there
/// indefinitely. These tests pin down the replacement: top of the output, gone
/// on its own after [kNotificationDuration].
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  AppNotificationsNotifier notifier() =>
      container.read(appNotificationsProvider.notifier);

  /// The overlay laid over a stand-in for the terminal, the way [HomeScreen]
  /// stacks it, so "at the top" is measurable.
  Future<void> pumpOverlay(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: Colors.black)),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: NotificationOverlay(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Runs the hold and the fade out, so nothing is left pending at teardown —
  /// a still-running timer fails the test on its way out, which reads as an
  /// unrelated failure.
  Future<void> expire(WidgetTester tester) async {
    await tester.pump(kNotificationDuration);
    await tester.pump(kNotificationFadeDuration + const Duration(milliseconds: 50));
  }

  testWidgets('costs no height while nothing is showing', (tester) async {
    await pumpOverlay(tester);
    // Stretched to the terminal's width by the Positioned, but zero-height and
    // pointer-transparent — so it can live in the stack permanently.
    expect(tester.getSize(find.byType(NotificationOverlay)).height, 0);
  });

  testWidgets('shows the message at the top of the output', (tester) async {
    await pumpOverlay(tester);
    notifier().show("Ignoring 'a small orc'");
    await tester.pump();

    expect(find.text("Ignoring 'a small orc'"), findsOneWidget);

    final overlay = tester.getRect(find.byType(NotificationOverlay));
    final card = tester.getRect(find.text("Ignoring 'a small orc'"));
    // Top half of the terminal, hard against the overlay's own top edge —
    // the whole point of the change is that it is not down by the input bar.
    expect(card.top - overlay.top, lessThan(24));
    expect(card.center.dy, lessThan(300));

    await expire(tester);
  });

  testWidgets('fades out and removes itself after the hold', (tester) async {
    await pumpOverlay(tester);
    notifier().show('No command history yet');
    await tester.pump();

    // Fully visible for the whole hold.
    await tester.pump(kNotificationDuration - const Duration(milliseconds: 50));
    expect(_opacityOf(tester), 1.0);

    // Then fading, and still on screen while it does.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(kNotificationFadeDuration ~/ 2);
    final midFade = _opacityOf(tester);
    expect(midFade, lessThan(1.0));
    expect(midFade, greaterThan(0.0));

    // And gone once the fade completes, without anyone dismissing it.
    await tester.pump(kNotificationFadeDuration);
    expect(find.text('No command history yet'), findsNothing);
    expect(container.read(appNotificationsProvider), isEmpty);
  });

  testWidgets('action runs its callback and dismisses immediately',
      (tester) async {
    var undone = 0;
    await pumpOverlay(tester);
    notifier().show(
      "Ignoring 'a small orc'",
      actionLabel: 'Undo',
      onAction: () => undone++,
    );
    await tester.pump();

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(undone, 1);
    expect(find.text("Ignoring 'a small orc'"), findsNothing);
    expect(container.read(appNotificationsProvider), isEmpty);
  });

  testWidgets('stacks a burst without marching down over the output',
      (tester) async {
    await pumpOverlay(tester);
    for (var i = 1; i <= kMaxVisibleNotifications + 2; i++) {
      notifier().show('Message $i');
    }
    await tester.pump();

    // Oldest are dropped rather than queued: a stale confirmation is worth less
    // than the freshest one, and an unbounded stack would cover the output.
    expect(find.text('Message 1'), findsNothing);
    expect(find.text('Message 2'), findsNothing);
    expect(find.text('Message ${kMaxVisibleNotifications + 2}'), findsOneWidget);
    expect(container.read(appNotificationsProvider).length,
        kMaxVisibleNotifications);

    await expire(tester);
  });

  testWidgets('an error notification paints in the error colour',
      (tester) async {
    await pumpOverlay(tester);
    notifier().show('File not found', isError: true);
    await tester.pump();

    final context = tester.element(find.text('File not found'));
    final style = tester.widget<Text>(find.text('File not found')).style!;
    expect(style.color, Theme.of(context).colorScheme.error);

    await expire(tester);
  });

  test('dismiss is idempotent, so two mounted overlays can both expire it', () {
    final id = container.read(appNotificationsProvider.notifier).show('hi');
    final notifier = container.read(appNotificationsProvider.notifier);
    notifier.dismiss(id);
    notifier.dismiss(id);
    expect(container.read(appNotificationsProvider), isEmpty);
  });
}

/// The card's current opacity, read off the [FadeTransition] `AnimatedOpacity`
/// builds — the animation is the thing under test, so it is read rather than
/// assumed from elapsed time.
double _opacityOf(WidgetTester tester) {
  final fade = tester.widget<FadeTransition>(
    find
        .descendant(
          of: find.byType(NotificationOverlay),
          matching: find.byType(FadeTransition),
        )
        .first,
  );
  return fade.opacity.value;
}
