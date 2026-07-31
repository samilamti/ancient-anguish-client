import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart';
import 'package:ancient_anguish_client/providers/login_provider.dart';
import 'package:ancient_anguish_client/providers/storage_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';
import 'package:ancient_anguish_client/services/storage/storage_service.dart';

/// The login dialog lists remembered characters in stored order and the 1-9
/// quick-login shortcuts index straight into it, so "most recently played
/// first" has to be true of the persisted list, not just of a display sort.
void main() {
  SavedAlt alt(String name, {DateTime? played}) =>
      SavedAlt(name: name, password: 'pw', lastPlayed: played);

  group('sortAltsByRecency', () {
    test('orders most recently played first', () {
      final sorted = sortAltsByRecency([
        alt('Old', played: DateTime(2026, 1, 1)),
        alt('Newest', played: DateTime(2026, 7, 30)),
        alt('Middle', played: DateTime(2026, 5, 5)),
      ]);
      expect(sorted.map((a) => a.name), ['Newest', 'Middle', 'Old']);
    });

    test('characters with no timestamp sort last, keeping their order', () {
      // Pre-`lastPlayed` saves: "never recorded" is not evidence of recency.
      final sorted = sortAltsByRecency([
        alt('NoStampA'),
        alt('Played', played: DateTime(2026, 1, 1)),
        alt('NoStampB'),
      ]);
      expect(sorted.map((a) => a.name), ['Played', 'NoStampA', 'NoStampB']);
    });

    test('does not mutate its argument', () {
      final input = [
        alt('A', played: DateTime(2026, 1, 1)),
        alt('B', played: DateTime(2026, 2, 2)),
      ];
      sortAltsByRecency(input);
      expect(input.map((a) => a.name), ['A', 'B']);
    });

    test('an alts.json written before the fix reads back newest-first', () {
      // Stored in first-saved order with good timestamps — the exact state an
      // upgrading install is in.
      final stored = [
        alt('FirstSaved', played: DateTime(2026, 1, 1)),
        alt('PlayedDaily', played: DateTime(2026, 7, 31)),
      ];
      final reloaded = sortAltsByRecency([
        for (final a in stored) SavedAlt.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>),
      ]);
      expect(reloaded.first.name, 'PlayedDaily');
    });
  });

  group('LoginNotifier saved-alt ordering', () {
    late ProviderContainer container;
    late _MemoryStorage storage;

    setUp(() {
      storage = _MemoryStorage();
      container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          connectionServiceProvider.overrideWithValue(_FakeConnection()),
          terminalBufferProvider.overrideWith(_FakeBuffer.new),
          promptParserProvider.overrideWithValue(PromptParser()),
          areaDetectorProvider
              .overrideWith((ref) => Future.value(AreaDetector())),
          unifiedAreaConfigProvider
              .overrideWith((ref) => Future.value(UnifiedAreaConfigManager())),
        ],
      );
      addTearDown(container.dispose);
    });

    Future<List<String>> storedNames() async {
      final raw = storage.files['alts.json'] ?? '[]';
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map((e) => e['name'] as String).toList();
    }

    Future<void> login(String name) async {
      container
          .read(loginProvider.notifier)
          .submitCredentials(name, 'pw', true);
      // _saveAlt is fire-and-forget; let the read/write round trip settle.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('a new character is stored at the front', () async {
      await login('Alpha');
      await login('Beta');
      expect(await storedNames(), ['Beta', 'Alpha']);
    });

    test('replaying an existing character moves it to the top', () async {
      // The bug this covers: the old code updated the entry in place, so the
      // alt you play every day kept whatever position it was first saved at.
      await login('Alpha');
      await login('Beta');
      await login('Gamma');
      expect(await storedNames(), ['Gamma', 'Beta', 'Alpha']);

      await login('Alpha');
      expect(await storedNames(), ['Alpha', 'Gamma', 'Beta']);
    });

    test('replaying does not duplicate the entry', () async {
      await login('Alpha');
      await login('Alpha');
      expect(await storedNames(), ['Alpha']);
    });

    test('the password is refreshed on replay', () async {
      await login('Alpha');
      container
          .read(loginProvider.notifier)
          .submitCredentials('Alpha', 'newpw', true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final list = (jsonDecode(storage.files['alts.json']!) as List)
          .cast<Map<String, dynamic>>();
      expect(list.single['password'], 'newpw');
    });

    test('an unremembered login leaves the list alone', () async {
      await login('Alpha');
      container
          .read(loginProvider.notifier)
          .submitCredentials('Guest', 'pw', false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(await storedNames(), ['Alpha']);
    });
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

class _FakeConnection extends TcpConnectionService {
  @override
  void sendCommand(String command) {}
}

class _FakeBuffer extends TerminalBufferNotifier {
  @override
  List<StyledLine> build() => [];
}
