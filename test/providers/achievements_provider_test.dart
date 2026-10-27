import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/achievement.dart';
import 'package:ancient_anguish_client/providers/achievements_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/providers/social_panel_provider.dart';
import 'package:ancient_anguish_client/providers/storage_provider.dart';
import 'package:ancient_anguish_client/services/storage/storage_service.dart';
import 'package:ancient_anguish_client/ui/widgets/social/social_panel.dart';

void main() {
  group('AchievementParser', () {
    test('a skill gain is an achievement with a party icon', () {
      final a = AchievementParser.match('Your skill in Spear has gone up!',
          now: DateTime(2026, 10, 23, 14, 5));
      expect(a, isNotNull);
      expect(a!.icon, '🎉');
      expect(a.text, 'Your skill in Spear has gone up!');
      expect(a.timestamp, DateTime(2026, 10, 23, 14, 5));
    });

    test('multi-word skills and surrounding whitespace still match', () {
      final a = AchievementParser.match('  Your skill in Two handed sword has gone up!  ');
      expect(a?.text, 'Your skill in Two handed sword has gone up!');
    });

    test('a skill gain with the new value suffix matches', () {
      final a = AchievementParser.match(
          'Your skill in Unarmed has gone up! You now have 1.');
      expect(a?.text, 'Your skill in Unarmed has gone up! You now have 1.');
      expect(
          AchievementParser.match(
              'Your skill in Two handed sword has gone up! You now have 100.'),
          isNotNull);
    });

    test('ordinary lines and lookalikes do not match', () {
      expect(
          AchievementParser.match(
              'Bob says: Your skill in Unarmed has gone up! You now have 1.'),
          isNull);
      expect(
          AchievementParser.match(
              'Your skill in Unarmed has gone up! You now have .'),
          isNull);
      expect(AchievementParser.match('You hit the orc.'), isNull);
      expect(
          AchievementParser.match('Bob says: Your skill in Spear has gone up!'),
          isNull);
      expect(AchievementParser.match('Your skill in Spear has gone down!'),
          isNull);
    });
  });

  group('AchievementsNotifier', () {
    test('persists and reloads, keeping anything added before the load',
        () async {
      final storage = _MemoryStorage()
        ..files['Achievements.json'] = jsonEncode([
          Achievement(
                  icon: '🎉',
                  text: 'Your skill in Axe has gone up!',
                  timestamp: DateTime(2026, 1, 1))
              .toJson(),
        ]);
      final container = ProviderContainer(overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(achievementsProvider.notifier);
      notifier.add(Achievement(
          icon: '🎉',
          text: 'Your skill in Spear has gone up!',
          timestamp: DateTime(2026, 10, 23)));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final texts =
          container.read(achievementsProvider).map((a) => a.text).toList();
      expect(texts, [
        'Your skill in Axe has gone up!',
        'Your skill in Spear has gone up!',
      ]);

      // A later add writes the merged list back.
      notifier.add(Achievement(
          icon: '🎉',
          text: 'Your skill in Bow has gone up!',
          timestamp: DateTime(2026, 10, 24)));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final saved = jsonDecode(storage.files['Achievements.json']!) as List;
      expect(saved, hasLength(3));
    });
  });

  test('achievementsEnabled defaults on and round-trips', () {
    expect(const AppSettings().achievementsEnabled, isTrue);
    expect(AppSettings.fromJson({}).achievementsEnabled, isTrue);
    final off = const AppSettings().copyWith(achievementsEnabled: false);
    expect(AppSettings.fromJson(off.toJson()).achievementsEnabled, isFalse);
  });

  testWidgets('tabbed cluster shows the Achievements tab and its entries',
      (tester) async {
    final storage = _MemoryStorage();
    final container = ProviderContainer(overrides: [
      storageServiceProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);

    container.read(achievementsProvider.notifier).add(Achievement(
        icon: '🎉',
        text: 'Your skill in Spear has gone up!',
        timestamp: DateTime(2026, 10, 23, 9, 7)));
    container.read(socialPanelProvider.notifier).setActiveTab(4);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: SocialPanel(panelType: SocialPanelType.tabbed),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('🏆 Achievements'), findsOneWidget);
    expect(find.text('Your skill in Spear has gone up!'), findsOneWidget);
    expect(find.text('2026-10-23 09:07'), findsOneWidget);
    expect(find.text('🎉'), findsOneWidget);
  });
}

class _MemoryStorage extends StorageService {
  final Map<String, String> files = {};

  @override
  Future<String> readFile(String name) async => files[name] ?? '';

  @override
  Future<List<String>> readFileLines(String name) async {
    final contents = await readFile(name);
    return contents.isEmpty ? [] : contents.split('\n');
  }

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
