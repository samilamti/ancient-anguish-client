import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/sheet.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart'
    show areaDetectorProvider, promptParserProvider;
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/providers/sheet_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';

import 'fake_connection_service.dart';

/// End-to-end: real bytes into [TerminalBufferNotifier], assertions on what the
/// player ends up seeing and what sheets were captured.
void main() {
  late FakeConnectionService fakeService;
  late ProviderContainer container;

  const skills = [
    'Your skills:',
    'Axe                   14              Polearm                4      ',
    'Club                  16              Rapier                18      ',
    'Knife                 23              Two Handed Axe         9      ',
  ];

  const shopList = [
    '#_of_ _Item_________________________________________________________ _cost_',
    '   1  A green shield................................................   800',
    '   1  A silver goblin shield........................................  1400',
    '   2  A small wooden shield.........................................   100',
  ];

  ProviderContainer newContainer({bool sheetsEnabled = true}) {
    final c = ProviderContainer(
      overrides: [
        connectionServiceProvider.overrideWithValue(fakeService),
        promptParserProvider.overrideWithValue(PromptParser()),
        areaDetectorProvider.overrideWith((ref) => Future.value(AreaDetector())),
        unifiedAreaConfigProvider.overrideWith(
            (ref) => Future.value(UnifiedAreaConfigManager())),
      ],
    );
    c.read(settingsProvider.notifier).loadFromJson({
      'sheetsEnabled': sheetsEnabled,
    });
    c.read(terminalBufferProvider.notifier);
    return c;
  }

  setUp(() => fakeService = FakeConnectionService());
  tearDown(() => container.dispose());

  Future<void> feed(Iterable<String> lines) async {
    fakeService.emitLines(lines);
    await Future.microtask(() {});
    await Future.microtask(() {});
  }

  List<String> buffer() =>
      container.read(terminalBufferProvider).map((l) => l.plainText).toList();

  /// The buffer's lines with any sheet sentinel replaced by a readable marker,
  /// so assertions stay legible.
  List<String> visible() => buffer()
      .map((l) => tryParseSheetId(l) != null ? '<sheet>' : l)
      .toList();

  List<Sheet> sheets() => container.read(sheetsProvider).values.toList();

  group('capture into the buffer', () {
    test('a skills block becomes one sheet line', () async {
      container = newContainer();
      // A trailing non-matching line closes the block.
      await feed([...skills, 'You feel stronger.']);

      expect(visible(), ['<sheet>', 'You feel stronger.']);
      expect(sheets().single, isA<SkillsSheet>());
    });

    test('a shop listing becomes one sheet line', () async {
      container = newContainer();
      await feed([...shopList, 'The shopkeeper waits.']);

      expect(visible(), ['<sheet>', 'The shopkeeper waits.']);
      final sheet = sheets().single as ShopListSheet;
      expect(sheet.items, hasLength(3));
    });

    test('the sentinel resolves to the captured sheet', () async {
      container = newContainer();
      await feed([...skills, 'done']);

      final sentinel = buffer().first;
      final id = tryParseSheetId(sentinel);
      expect(id, isNotNull);
      expect(container.read(sheetsProvider)[id], isA<SkillsSheet>());
    });

    test('ordinary output around a sheet is untouched', () async {
      container = newContainer();
      await feed([
        'You see a forest.',
        ...skills,
        'The path leads east.',
      ]);
      expect(visible(), ['You see a forest.', '<sheet>', 'The path leads east.']);
    });

    test('two sheets in one batch both land', () async {
      container = newContainer();
      await feed([...skills, ...shopList, 'done']);

      expect(visible(), ['<sheet>', '<sheet>', 'done']);
      expect(sheets(), hasLength(2));
    });
  });

  group('nothing is ever lost', () {
    test('a block that is not a sheet is released verbatim', () async {
      container = newContainer();
      const notASheet = [
        'Your skills:',
        'You have not learned any weapons.',
        'Try the guild.',
      ];
      await feed(notASheet);
      // Flushed by nothing yet — the third line terminated the block.
      expect(visible(), notASheet);
      expect(sheets(), isEmpty);
    });

    test('a block split across packets still becomes one sheet', () async {
      // A 29-item listing does not arrive in one TCP segment.
      container = newContainer();
      await feed(shopList.take(2));
      await feed(shopList.skip(2));
      await feed(['The shopkeeper waits.']);

      expect(visible(), ['<sheet>', 'The shopkeeper waits.']);
      expect((sheets().single as ShopListSheet).items, hasLength(3));
    });

    test('a prompt closes a block nothing else terminated', () async {
      // Without the flush the block would sit in the capture and the player
      // would simply never see their skills. Prompts are only recognised after
      // login, which is what gates the flush.
      container = newContainer();
      container.read(terminalBufferProvider.notifier).setLoginDetected();
      await feed(skills);
      expect(visible(), isEmpty, reason: 'still accumulating');

      // The payload is bare values in canonical element order — hp, maxhp,
      // sp, maxsp, x, y — not labelled pairs.
      await feed(['@@100 100 50 50 1 2@@']);
      // The prompt itself is gagged, so the sheet is all that lands.
      expect(visible(), ['<sheet>']);
      expect(sheets().single, isA<SkillsSheet>());
    });
  });

  group('the setting', () {
    test('with sheets off the raw text reaches the buffer', () async {
      container = newContainer(sheetsEnabled: false);
      await feed([...skills, 'done']);

      expect(buffer(), [...skills, 'done']);
      expect(sheets(), isEmpty);
    });

    test('turning sheets off mid-block releases the held lines', () async {
      // The lines held so far must not vanish just because the flag flipped.
      container = newContainer();
      await feed(skills);
      expect(visible(), isEmpty);

      container.read(settingsProvider.notifier).toggleSheets();
      await feed(['done']);

      expect(buffer(), [...skills, 'done']);
      expect(sheets(), isEmpty);
    });
  });

  group('clearing', () {
    test('clear drops the captured sheets and their view state', () async {
      container = newContainer();
      await feed([...skills, 'done']);
      final id = tryParseSheetId(buffer().first)!;
      container.read(expandedSheetsProvider.notifier).toggle(id);
      container.read(costSortedSheetsProvider.notifier).toggle(id);

      container.read(terminalBufferProvider.notifier).clear();

      expect(buffer(), isEmpty);
      expect(sheets(), isEmpty);
      expect(container.read(expandedSheetsProvider), isEmpty);
      expect(container.read(costSortedSheetsProvider), isEmpty);
    });
  });
}
