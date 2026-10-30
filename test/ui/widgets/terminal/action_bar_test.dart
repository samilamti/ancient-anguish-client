import 'package:ancient_anguish_client/models/alias_rule.dart';
import 'package:ancient_anguish_client/providers/alias_provider.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/play_mode_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/providers/target_provider.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/action_bar.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/play_mode.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectionService extends TcpConnectionService {
  final List<String> sent = [];

  @override
  bool get isConnected => true;

  @override
  void sendCommand(String command) => sent.add(command);
}

void main() {
  late _FakeConnectionService service;

  const fb = AliasRule(
      id: 'fb', keyword: 'fb', expansion: r'kill $target;cast fireball $target');
  const heal = AliasRule(
      id: 'heal', keyword: 'heal', expansion: 'cast cure;drink potion');

  Future<ProviderContainer> pumpBar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    service = _FakeConnectionService();
    await tester.pumpWidget(ProviderScope(
      overrides: [connectionServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        home: Scaffold(
          body: PlayModeKeys(
            available: true,
            onSlot: runActionBarSlot,
            child: Column(
              children: [Expanded(child: SizedBox()), ActionBar()],
            ),
          ),
        ),
      ),
    ));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ActionBar)));
    final aliases = container.read(aliasRulesProvider.notifier);
    aliases.addRule(fb);
    aliases.addRule(heal);
    final settings = container.read(settingsProvider.notifier);
    settings.setActionBarSlot(0, 'fb');
    settings.setActionBarSlot(9, 'heal');
    container.read(playModeProvider.notifier).setEnabled(true);
    await tester.pump();
    await tester.pump();
    return container;
  }

  test('settings keep ten slots and round-trip them', () {
    const s = AppSettings();
    expect(s.actionBarAliasIds, hasLength(10));
    final json = s.copyWith(actionBarAliasIds: [
      'a', null, null, null, null, null, null, null, null, 'z',
    ]).toJson();
    final back = AppSettings.fromJson(json);
    expect(back.actionBarAliasIds.first, 'a');
    expect(back.actionBarAliasIds.last, 'z');
    // A short or missing list still gives ten slots.
    expect(AppSettings.fromJson({'actionBarAliasIds': ['a']}).actionBarAliasIds,
        hasLength(10));
    expect(AppSettings.fromJson(const {}).actionBarAliasIds, hasLength(10));
  });

  testWidgets('slots show key and keyword, empty ones a +', (tester) async {
    await pumpBar(tester);
    expect(find.text('fb'), findsOneWidget);
    expect(find.text('heal'), findsOneWidget);
    expect(find.text('+'), findsNWidgets(8));
  });

  testWidgets('keys 1 and 0 fire their aliases', (tester) async {
    final container = await pumpBar(tester);
    container.read(targetProvider.notifier).set('orc 2');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5); // empty slot
    expect(service.sent, [
      'kill orc 2', 'cast fireball orc 2', 'cast cure', 'drink potion',
    ]);
  });

  testWidgets(r'a $target slot with no target sends nothing and says so',
      (tester) async {
    final container = await pumpBar(tester);
    await tester.tap(find.text('fb'));
    await tester.pump();
    expect(service.sent, isEmpty);
    expect(container.read(terminalBufferProvider).last.plainText, 'No target.');
  });

  testWidgets(r'a $target slot is dimmed until a target is set',
      (tester) async {
    final container = await pumpBar(tester);
    double opacityOf(String label) => tester
        .widget<Opacity>(
            find.ancestor(of: find.text(label), matching: find.byType(Opacity)))
        .opacity;
    expect(opacityOf('fb'), lessThan(1));
    expect(opacityOf('heal'), 1);
    container.read(targetProvider.notifier).set('orc');
    await tester.pump();
    expect(opacityOf('fb'), 1);
  });

  testWidgets('right-click assigns an alias; clear empties the slot',
      (tester) async {
    final container = await pumpBar(tester);
    await tester.tap(find.text('+').first, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Slot 2'), findsOneWidget);
    await tester.tap(find.text('heal').last);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).actionBarAliasIds[1], 'heal');

    await tester.tap(find.text('fb'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear slot'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).actionBarAliasIds[0], isNull);
  });

  testWidgets('an auto-added command shows and fires from its slot',
      (tester) async {
    final container = await pumpBar(tester);
    container
        .read(settingsProvider.notifier)
        .autoAddActionBarCommand('drink potion');
    await tester.pump();
    expect(container.read(settingsProvider).actionBarCommands[1],
        'drink potion');
    expect(find.text('drink potion'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    expect(service.sent, ['drink potion']);
  });
}
