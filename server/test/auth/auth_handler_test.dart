import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:ancient_anguish_server/src/auth/auth_handler.dart';
import 'package:ancient_anguish_server/src/auth/jwt_service.dart';
import 'package:ancient_anguish_server/src/auth/user_store.dart';

void main() {
  late Directory tempDir;
  late UserStore userStore;
  late JwtService jwtService;
  late AuthHandler handler;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('auth_handler_test_');
    userStore = UserStore(tempDir.path);
    jwtService = JwtService('test-secret-that-is-at-least-32-chars!!');
    handler = AuthHandler(userStore, jwtService);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<Response> postJson(String path, Map<String, dynamic> body) {
    final request = Request(
      'POST',
      Uri.parse('http://localhost$path'),
      body: jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );
    return handler.router.call(request);
  }

  group('AuthHandler', () {
    group('register', () {
      test('succeeds with valid credentials', () async {
        final response = await postJson('/register', {
          'username': 'testuser',
          'password': 'testpass123',
        });
        expect(response.statusCode, 201);

        final body = jsonDecode(await response.readAsString());
        expect(body['token'], isNotEmpty);
        expect(body['username'], 'testuser');
      });

      test('returns 400 for missing fields', () async {
        final response = await postJson('/register', {
          'username': 'testuser',
        });
        expect(response.statusCode, 400);
      });

      test('returns 409 for duplicate username', () async {
        await postJson('/register', {
          'username': 'testuser',
          'password': 'testpass123',
        });
        final response = await postJson('/register', {
          'username': 'testuser',
          'password': 'otherpass1',
        });
        expect(response.statusCode, 409);
      });

      test('returns 400 for invalid JSON', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/register'),
          body: 'not json',
        );
        final response = await handler.router.call(request);
        expect(response.statusCode, 400);
      });
    });

    group('login', () {
      setUp(() async {
        await postJson('/register', {
          'username': 'testuser',
          'password': 'testpass123',
        });
      });

      test('succeeds with correct credentials', () async {
        final response = await postJson('/login', {
          'username': 'testuser',
          'password': 'testpass123',
        });
        expect(response.statusCode, 200);

        final body = jsonDecode(await response.readAsString());
        expect(body['token'], isNotEmpty);
        expect(body['username'], 'testuser');
      });

      test('returns 401 for wrong password', () async {
        final response = await postJson('/login', {
          'username': 'testuser',
          'password': 'wrongpassword',
        });
        expect(response.statusCode, 401);
      });

      test('returns 401 for non-existent user', () async {
        final response = await postJson('/login', {
          'username': 'nobody',
          'password': 'testpass123',
        });
        expect(response.statusCode, 401);
      });
    });
  });
}
