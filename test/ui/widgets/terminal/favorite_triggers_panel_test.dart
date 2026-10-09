import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/meter_condition.dart';
import 'package:ancient_anguish_client/models/text_link_rule.dart';
import 'package:ancient_anguish_client/providers/command_trigger_provider.dart';
import 'package:ancient_anguish_client/providers/storage_provider.dart';
import 'package:ancient_anguish_client/services/storage/storage_service.dart';
import 'package:ancient_anguish_client/ui/screens/text_link_rules_screen.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/favorite_triggers_panel.dart';

class _MemoryStorage extends StorageService {
  final Map<String, String> files = {};

  @override
  Future<String> readFile(String name) async => files[name] ?? '';
  @override
  Future<List<String>> readFileLines(String name) async =>
      (files[name] ?? '').split('\n');
  @override
  Future<void> writeFile(String name, String contents) async =>
      files[name] = contents;
  @override
  Future<void> appendToFile(String name, String text) async =>
      files[name] = (files[name] ?? '') + text;
  @override
  Future<bool> fileExists(String name) async => files.containsKey(name);
  @override
  Future<int> fileLength(String name) async => (files[name] ?? '').length;
  @override
  Future<void> ensureFile(String name, [String defaultContents = '']) async =>
      files.putIfAbsent(name, () => defaultContents);
  @override
  Future<void> ensureDirectories() async {}
}

const _rules = [
  TextLinkRule(
    id: 'ctr_1',
    name: 'Rescue',
    pattern: 'help',
    commandTemplate: 'rescue',
    favorite: true,
  ),
  TextLinkRule(
    id: 'ctr_2',
    name: 'Eat',
    pattern: 'hungry',
    commandTemplate: 'eat bread',
  ),
];

void main() {
  late _MemoryStorage storage;

  setUp(() {
    storage = _MemoryStorage();
    storage.files['Command Triggers.json'] =
        jsonEncode(_rules.map((r) => r.toJson()).toList());
  });

  Future<ProviderContainer> pump(WidgetTester tester, Widget child,
      {bool local = true}) async {
    final container = ProviderContainer(overrides: [
      storageServiceProvider.overrideWithValue(storage),
      localFeaturesAvailableProvider.overrideWith((ref) async => local),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  test('favorite survives a JSON round trip and defaults to false', () {
    final back = TextLinkRule.fromJson(_rules[0].toJson());
    expect(back.favorite, isTrue);
    expect(_rules[1].toJson().containsKey('favorite'), isFalse);
    expect(TextLinkRule.fromJson(_rules[1].toJson()).favorite, isFalse);
  });

  testWidgets('panel lists only starred triggers and toggles them',
      (tester) async {
    final container = await pump(
      tester,
      const Stack(children: [Positioned.fill(child: FavoriteTriggersOverlay())]),
    );

    expect(find.text('Rescue'), findsOneWidget);
    expect(find.text('Eat'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final rescue = container
        .read(commandTriggerRulesProvider)
        .firstWhere((r) => r.id == 'ctr_1');
    expect(rescue.enabled, isFalse);
    expect(rescue.favorite, isTrue);
  });

  testWidgets('panel is absent without the local-features marker',
      (tester) async {
    await pump(
      tester,
      const Stack(children: [Positioned.fill(child: FavoriteTriggersOverlay())]),
      local: false,
    );
    expect(find.byKey(const ValueKey('favoriteTriggersPanel')), findsNothing);
  });

  testWidgets('starring in the trigger list adds it to the favourites',
      (tester) async {
    final container = await pump(
      tester,
      const TextLinkRulesScreen(kind: RuleListKind.commandTrigger),
    );
    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();
    expect(
      container.read(commandTriggerRulesProvider).every((r) => r.favorite),
      isTrue,
    );
  });

  testWidgets('an unnamed trigger saves under a default name',
      (tester) async {
    final container = await pump(
      tester,
      Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => openTextLinkRuleEditor(ctx,
              initialMatchText: 'You are hungry.',
              kind: RuleListKind.commandTrigger),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Two triggers exist, so the next free default is "Trigger 3".
    expect(find.text('Defaults to Trigger 3'), findsOneWidget);

    // Leaving the name empty still saves, under the default.
    await tester.enterText(
        find.widgetWithText(TextField, 'Command template'), 'eat');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final names =
        container.read(commandTriggerRulesProvider).map((r) => r.name);
    expect(names, contains('Trigger 3'));
  });

  testWidgets('a meter-colour trigger saves its condition and no pattern',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await pump(
      tester,
      Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => openTextLinkRuleEditor(ctx,
              kind: RuleListKind.commandTrigger),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Meter colour'));
    await tester.pumpAndSettle();
    // The regex field and its test area go away.
    expect(find.widgetWithText(TextField, 'Pattern (regex)'), findsNothing);
    expect(find.text('Test the rule'), findsNothing);

    // HP → SP, then pick cyan.
    await tester.tap(find.byKey(const ValueKey('meter_trigger_meter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SP').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('meter_trigger_band_sp')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cyan').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Command'), 'cast heal');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final saved = container
        .read(commandTriggerRulesProvider)
        .firstWhere((r) => r.commandTemplate == 'cast heal');
    expect(saved.meter?.meter, Meter.sp);
    expect(saved.meter?.band, 'cyan');
    // Switching meter resets the direction to one every band can satisfy.
    expect(saved.meter?.direction, MeterDirection.either);
    expect(saved.pattern, isEmpty);
  });
}
