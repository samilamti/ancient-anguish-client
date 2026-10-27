import 'package:ancient_anguish_client/providers/room_targets_provider.dart';
import 'package:ancient_anguish_client/providers/target_provider.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/target_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProviderContainer> pumpChip(WidgetTester tester,
      {bool hideWhenEmpty = false}) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: TargetChip(hideWhenEmpty: hideWhenEmpty)),
      ),
    ));
    return ProviderScope.containerOf(tester.element(find.byType(TargetChip)));
  }

  void enterRoom(ProviderContainer c, List<String> lines) {
    final rooms = c.read(roomTargetsProvider.notifier);
    for (final l in ['Forest (n)', ...lines, '']) {
      rooms.processLine(l);
    }
  }

  testWidgets('names the target and hints Tab when there is more',
      (tester) async {
    final c = await pumpChip(tester);
    expect(find.text('🎯 no target'), findsOneWidget);
    enterRoom(c, ['An orc.', 'An orc.']);
    c.read(targetProvider.notifier).set('orc');
    await tester.pump();
    expect(find.text('🎯 orc'), findsOneWidget);
    expect(find.text('Tab'), findsOneWidget);
  });

  testWidgets('tapping it moves to the next target', (tester) async {
    final c = await pumpChip(tester);
    enterRoom(c, ['An orc.', 'A wild boar.']);
    await tester.tap(find.byType(TargetChip));
    await tester.pump();
    expect(c.read(targetProvider), 'orc');
    expect(find.text('🎯 orc'), findsOneWidget);
  });

  testWidgets('the phone chip is hidden with no target', (tester) async {
    final c = await pumpChip(tester, hideWhenEmpty: true);
    expect(find.textContaining('🎯'), findsNothing);
    c.read(targetProvider.notifier).set('rat');
    await tester.pump();
    expect(find.text('🎯 rat'), findsOneWidget);
    expect(find.text('Tab'), findsNothing);
  });
}
