import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/logging/log_service.dart';
import 'package:ancient_anguish_client/services/storage/storage_service.dart';

/// In-memory [StorageService] for tests.
class InMemoryStorageService extends StorageService {
  final Map<String, String> files = {};

  @override
  Future<String> readFile(String name) async => files[name] ?? '';

  @override
  Future<List<String>> readFileLines(String name) async {
    final content = files[name] ?? '';
    if (content.isEmpty) return [];
    return content.split('\n');
  }

  @override
  Future<void> writeFile(String name, String contents) async {
    files[name] = contents;
  }

  @override
  Future<void> appendToFile(String name, String text) async {
    files[name] = (files[name] ?? '') + text;
  }

  @override
  Future<bool> fileExists(String name) async => files.containsKey(name);

  @override
  Future<int> fileLength(String name) async =>
      (files[name] ?? '').length;

  @override
  Future<void> ensureFile(String name, [String defaultContents = '']) async {
    files.putIfAbsent(name, () => defaultContents);
  }

  @override
  Future<void> ensureDirectories() async {}
}

void main() {
  late LogService service;
  late InMemoryStorageService storage;

  setUp(() {
    storage = InMemoryStorageService();
    service = LogService();
  });

  tearDown(() async {
    await service.dispose();
  });

  group('LogService', () {
    test('initial state is not enabled and has no log name', () {
      expect(service.isEnabled, false);
      expect(service.currentLogName, isNull);
    });

    test('startLogging sets enabled and creates file', () async {
      await service.startLogging(storage);
      expect(service.isEnabled, true);
      expect(service.currentLogName, isNotNull);
      expect(storage.files.containsKey(service.currentLogName!), true);
    });

    test('startLogging when already enabled is a no-op', () async {
      await service.startLogging(storage);
      final firstName = service.currentLogName;
      await service.startLogging(storage);
      expect(service.currentLogName, firstName);
    });

    test('logLine when disabled is a no-op', () {
      service.logLine('should not appear');
      expect(service.isEnabled, false);
    });

    test('logLine when enabled writes text to file', () async {
      await service.startLogging(storage);
      final logName = service.currentLogName!;
      service.logLine('Hello World');
      // Flush and stop to ensure writes complete.
      await service.stopLogging();

      final contents = storage.files[logName]!;
      expect(contents, contains('Hello World'));
    });

    test('logSystem writes *** message format', () async {
      await service.startLogging(storage);
      final logName = service.currentLogName!;
      service.logSystem('Connected');
      await service.stopLogging();

      final contents = storage.files[logName]!;
      expect(contents, contains('*** Connected'));
    });

    test('stopLogging writes session ended marker and resets state', () async {
      await service.startLogging(storage);
      final logName = service.currentLogName!;
      await service.stopLogging();

      expect(service.isEnabled, false);
      final contents = storage.files[logName]!;
      expect(contents, contains('Session ended'));
    });

    test('stopLogging when not enabled is a no-op', () async {
      await service.stopLogging();
      expect(service.isEnabled, false);
    });

    test('dispose calls stopLogging', () async {
      await service.startLogging(storage);
      final logName = service.currentLogName!;
      await service.dispose();

      expect(service.isEnabled, false);
      final contents = storage.files[logName]!;
      expect(contents, contains('Session ended'));
    });

    test('startLogging writes session started marker', () async {
      await service.startLogging(storage);
      final logName = service.currentLogName!;
      await service.stopLogging();

      final contents = storage.files[logName]!;
      expect(contents, contains('Session started'));
    });
  });
}
