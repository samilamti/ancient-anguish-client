import 'dart:io';

import 'package:test/test.dart';

import 'package:ancient_anguish_server/src/auth/user_store.dart';

void main() {
  late Directory tempDir;
  late UserStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('user_store_test_');
    store = UserStore(tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('UserStore', () {
    test('register creates a new user', () async {
      final error = await store.register('alice', 'password123');
      expect(error, isNull);
      expect(store.userExists('alice'), isTrue);
    });

    test('register rejects short username', () async {
      final error = await store.register('ab', 'password123');
      expect(error, contains('3-30'));
    });

    test('register rejects short password', () async {
      final error = await store.register('alice', 'short');
      expect(error, contains('8 characters'));
    });

    test('register rejects invalid username characters', () async {
      final error = await store.register('alice!@#', 'password123');
      expect(error, contains('alphanumeric'));
    });

    test('register rejects duplicate username (case insensitive)', () async {
      await store.register('alice', 'password123');
      final error = await store.register('Alice', 'password456');
      expect(error, contains('already taken'));
    });

    test('authenticate returns username for correct credentials', () async {
      await store.register('alice', 'password123');
      final result = await store.authenticate('alice', 'password123');
      expect(result, 'alice');
    });

    test('authenticate is case insensitive for username', () async {
      await store.register('Alice', 'password123');
      final result = await store.authenticate('alice', 'password123');
      expect(result, 'Alice'); // Returns canonical case.
    });

    test('authenticate returns null for wrong password', () async {
      await store.register('alice', 'password123');
      final result = await store.authenticate('alice', 'wrongpass');
      expect(result, isNull);
    });

    test('authenticate returns null for non-existent user', () async {
      final result = await store.authenticate('nobody', 'password123');
      expect(result, isNull);
    });

    test('users persist across load/save', () async {
      await store.register('alice', 'password123');

      // Create a new store pointing at the same directory.
      final store2 = UserStore(tempDir.path);
      await store2.load();
      expect(store2.userExists('alice'), isTrue);

      final result = await store2.authenticate('alice', 'password123');
      expect(result, 'alice');
    });
  });
}
