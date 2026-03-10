import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/logging/log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LogService service;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('log_service_test_');
    service = LogService();

    // Mock path_provider to return our temp directory.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );
  });

  tearDown(() async {
    await service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LogService', () {
    test('initial state is not enabled and has no log path', () {
      expect(service.isEnabled, false);
      expect(service.currentLogPath, isNull);
    });

    test('startLogging creates file and sets enabled', () async {
      await service.startLogging();
      expect(service.isEnabled, true);
      expect(service.currentLogPath, isNotNull);
      expect(File(service.currentLogPath!).existsSync(), true);
    });

    test('startLogging when already enabled is a no-op', () async {
      await service.startLogging();
      final firstPath = service.currentLogPath;
      await service.startLogging();
      expect(service.currentLogPath, firstPath);
    });

    test('logLine when disabled is a no-op', () {
      service.logLine('should not appear');
      // No error thrown, nothing to assert beyond no crash.
      expect(service.isEnabled, false);
    });

    test('logLine when enabled writes text to file', () async {
      await service.startLogging();
      service.logLine('Hello World');
      // Flush and stop to ensure writes complete.
      await service.stopLogging();

      final contents = File(service.currentLogPath!).readAsStringSync();
      expect(contents, contains('Hello World'));
    });

    test('logSystem writes *** message format', () async {
      await service.startLogging();
      service.logSystem('Connected');
      await service.stopLogging();

      final contents = File(service.currentLogPath!).readAsStringSync();
      expect(contents, contains('*** Connected'));
    });

    test('stopLogging writes session ended marker and resets state', () async {
      await service.startLogging();
      final path = service.currentLogPath!;
      await service.stopLogging();

      expect(service.isEnabled, false);
      final contents = File(path).readAsStringSync();
      expect(contents, contains('Session ended'));
    });

    test('stopLogging when not enabled is a no-op', () async {
      await service.stopLogging();
      expect(service.isEnabled, false);
    });

    test('dispose calls stopLogging', () async {
      await service.startLogging();
      final path = service.currentLogPath!;
      await service.dispose();

      expect(service.isEnabled, false);
      final contents = File(path).readAsStringSync();
      expect(contents, contains('Session ended'));
    });

    test('startLogging writes session started marker', () async {
      await service.startLogging();
      await service.stopLogging();

      final contents = File(service.currentLogPath!).readAsStringSync();
      expect(contents, contains('Session started'));
    });
  });
}
