import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/ui/screens/history_screen.dart';
import 'package:ancient_anguish_client/ui/widgets/common/settings_drawer_route.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        terminalBufferProvider.overrideWith(_FakeTerminalBufferNotifier.new),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpHistoryPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () =>
                    openSettingsDrawer(ctx, const HistoryScreen()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
  }

  testWidgets('History opens as a right-docked panel', (tester) async {
    await pumpHistoryPanel(tester);

    final paneRect = tester.getRect(find.byType(HistoryScreen));
    expect(paneRect.right, 800);
    expect(paneRect.left, greaterThan(100));
  });

  testWidgets('Escape closes the History panel', (tester) async {
    await pumpHistoryPanel(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('History'), findsNothing);
  });
}

/// Fake terminal buffer that skips connection-event listening.
class _FakeTerminalBufferNotifier extends TerminalBufferNotifier {
  @override
  List<StyledLine> build() => [];
}
