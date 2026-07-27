import 'package:ancient_anguish_client/services/command_history_service.dart';
import 'package:ancient_anguish_client/services/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory storage whose reads and writes each yield to the event loop —
/// enough for two un-serialised read-modify-write cycles to interleave, which
/// is exactly the corruption this suite guards against.
class _SlowStorage extends StorageService {
  final Map<String, String> files = {};
  int writes = 0;

  @override
  Future<String> readFile(String name) async {
    await Future<void>.delayed(Duration.zero);
    return files[name] ?? '';
  }

  @override
  Future<List<String>> readFileLines(String name) async {
    final contents = await readFile(name);
    if (contents.isEmpty) return [];
    return contents.split('\n');
  }

  @override
  Future<void> writeFile(String name, String contents) async {
    await Future<void>.delayed(Duration.zero);
    files[name] = contents;
    writes++;
  }

  @override
  Future<void> appendToFile(String name, String text) async {
    files[name] = (files[name] ?? '') + text;
  }

  @override
  Future<bool> fileExists(String name) async => (files[name] ?? '').isNotEmpty;

  @override
  Future<int> fileLength(String name) async => (files[name] ?? '').length;

  @override
  Future<void> ensureFile(String name, [String defaultContents = '']) async {
    files.putIfAbsent(name, () => defaultContents);
  }

  @override
  Future<void> ensureDirectories() async {}
}

void main() {
  group('CommandHistoryService.appendCommand', () {
    test('a burst of appends lands intact and in order', () async {
      final storage = _SlowStorage();
      const commands = [
        'score',
        'open north door',
        'read the notice board',
        'enter portal',
        'cast fireball at eagle',
      ];

      // Fire them without awaiting in between — the real notifier does
      // exactly this, one per keystroke-completed command.
      final pending = [
        for (final c in commands)
          CommandHistoryService.appendCommand(storage, c),
      ];
      await Future.wait(pending);

      final written = await storage.readFileLines('Command History.md');
      expect(written.where((l) => l.isNotEmpty).toList(), commands);
    });

    test('re-appending an existing command moves it to the end', () async {
      final storage = _SlowStorage();
      for (final c in ['alpha item', 'beta item', 'gamma item']) {
        await CommandHistoryService.appendCommand(storage, c);
      }
      await CommandHistoryService.appendCommand(storage, 'alpha item');

      final written = (await storage.readFileLines('Command History.md'))
          .where((l) => l.isNotEmpty)
          .toList();
      expect(written, ['beta item', 'gamma item', 'alpha item']);
    });

    test('caps the file at maxEntries, keeping the newest', () async {
      final storage = _SlowStorage();
      for (var i = 0; i < CommandHistoryService.maxEntries + 5; i++) {
        await CommandHistoryService.appendCommand(storage, 'command_$i');
      }
      final written = (await storage.readFileLines('Command History.md'))
          .where((l) => l.isNotEmpty)
          .toList();
      expect(written, hasLength(CommandHistoryService.maxEntries));
      expect(written.last,
          'command_${CommandHistoryService.maxEntries + 5 - 1}');
      expect(written.first, 'command_5');
    });
  });

  group('CommandHistoryService.loadHistory', () {
    test('returns newest-first and collapses duplicates', () async {
      final storage = _SlowStorage();
      storage.files['Command History.md'] =
          'alpha item\nbeta item\nalpha item\ngamma item\n';

      final loaded = await CommandHistoryService.loadHistory(storage);
      expect(loaded, ['gamma item', 'alpha item', 'beta item']);
    });
  });
}
