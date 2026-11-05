import 'package:ancient_anguish_client/services/social/social_history_service.dart';
import 'package:ancient_anguish_client/services/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<bool> fileExists(String name) async => (files[name] ?? '').isNotEmpty;

  @override
  Future<int> fileLength(String name) async => (files[name] ?? '').length;

  @override
  Future<void> ensureFile(String name, [String defaultContents = '']) async =>
      files.putIfAbsent(name, () => defaultContents);

  @override
  Future<void> ensureDirectories() async {}
}

String _today() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

void main() {
  test('a cleared chat stays cleared after reload, the file is kept', () async {
    final storage = _MemoryStorage();
    final file = 'Chat History/${_today()}.md';
    storage.files[file] = '09:15 Gandalf: Hello everyone!\n\n'
        '09:16 Frodo: Pretty rough actually\n\n';

    await SocialHistoryService.markCleared(storage,
        kind: SocialHistoryKind.chat);
    expect(await SocialHistoryService.loadChat(storage), isEmpty);

    storage.files[file] = '${storage.files[file]}09:17 Sam: Po-tay-toes\n\n';
    final after = await SocialHistoryService.loadChat(storage);
    expect(after.map((m) => m.sender), ['Sam']);
    expect(storage.files[file], contains('Gandalf'));
  });

  test('a marker from another day is ignored', () async {
    final storage = _MemoryStorage();
    storage.files['Tell History/${_today()}.md'] =
        '09:15 Gandalf tells you: Fly, you fools\n\n';
    storage.files['Tell History/.cleared'] = '2001-01-01 40';
    final tells = await SocialHistoryService.loadTells(storage);
    expect(tells, hasLength(1));
  });
}
