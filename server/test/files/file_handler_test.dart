import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:ancient_anguish_server/src/files/file_handler.dart';

void main() {
  late Directory tempDir;
  late FileHandler handler;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_handler_test_');
    handler = FileHandler(tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Creates a request with 'username' in context (simulating auth middleware).
  Request _authedRequest(
    String method,
    String path, {
    String? body,
    Map<String, String>? headers,
  }) {
    return Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body,
      headers: headers ?? {},
      context: {'username': 'testuser'},
    );
  }

  group('FileHandler', () {
    test('GET returns empty string for non-existent file', () async {
      final request = _authedRequest('GET', '/settings.json');
      final response = await handler.router.call(request);
      expect(response.statusCode, 200);
      expect(await response.readAsString(), '');
    });

    test('PUT writes file, GET reads it back', () async {
      // Write.
      final putRequest = _authedRequest('PUT', '/settings.json',
          body: '{"theme": "dark"}');
      final putResponse = await handler.router.call(putRequest);
      expect(putResponse.statusCode, 204);

      // Read.
      final getRequest = _authedRequest('GET', '/settings.json');
      final getResponse = await handler.router.call(getRequest);
      expect(getResponse.statusCode, 200);
      expect(await getResponse.readAsString(), '{"theme": "dark"}');
    });

    test('POST append adds text to existing file', () async {
      // Write initial.
      final putRequest = _authedRequest('PUT', '/settings.json',
          body: 'line1\n');
      await handler.router.call(putRequest);

      // Append.
      final appendRequest = _authedRequest('POST', '/settings.json/append',
          body: 'line2\n');
      final appendResponse = await handler.router.call(appendRequest);
      expect(appendResponse.statusCode, 204);

      // Read.
      final getRequest = _authedRequest('GET', '/settings.json');
      final getResponse = await handler.router.call(getRequest);
      expect(await getResponse.readAsString(), 'line1\nline2\n');
    });

    test('POST append creates file if it does not exist', () async {
      final appendRequest = _authedRequest('POST', '/settings.json/append',
          body: 'new content');
      final response = await handler.router.call(appendRequest);
      expect(response.statusCode, 204);

      final getRequest = _authedRequest('GET', '/settings.json');
      final getResponse = await handler.router.call(getRequest);
      expect(await getResponse.readAsString(), 'new content');
    });

    test('GET /meta returns file existence and length', () async {
      // Non-existent.
      final meta1 = _authedRequest('GET', '/settings.json/meta');
      final response1 = await handler.router.call(meta1);
      expect(response1.headers['x-file-exists'], 'false');

      // Write.
      final putRequest = _authedRequest('PUT', '/settings.json',
          body: 'hello');
      await handler.router.call(putRequest);

      // Exists.
      final meta2 = _authedRequest('GET', '/settings.json/meta');
      final response2 = await handler.router.call(meta2);
      expect(response2.headers['x-file-exists'], 'true');
      expect(response2.headers['x-file-length'], '5');
    });

    test('GET /lines returns JSON array of lines', () async {
      final putRequest = _authedRequest('PUT', '/settings.json',
          body: 'line1\nline2\nline3');
      await handler.router.call(putRequest);

      final getRequest = _authedRequest('GET', '/settings.json/lines');
      final response = await handler.router.call(getRequest);
      expect(response.statusCode, 200);

      final lines = jsonDecode(await response.readAsString()) as List;
      expect(lines, ['line1', 'line2', 'line3']);
    });

    test('GET /lines returns empty array for non-existent file', () async {
      final getRequest = _authedRequest('GET', '/settings.json/lines');
      final response = await handler.router.call(getRequest);
      final lines = jsonDecode(await response.readAsString()) as List;
      expect(lines, isEmpty);
    });

    test('POST ensure creates file with default content', () async {
      final request = _authedRequest('POST', '/settings.json/ensure',
          body: '{}');
      final response = await handler.router.call(request);
      expect(response.statusCode, 204);

      final getRequest = _authedRequest('GET', '/settings.json');
      final getResponse = await handler.router.call(getRequest);
      expect(await getResponse.readAsString(), '{}');
    });

    test('POST ensure does not overwrite existing file', () async {
      // Write.
      final putRequest = _authedRequest('PUT', '/settings.json',
          body: 'existing');
      await handler.router.call(putRequest);

      // Ensure.
      final ensureRequest = _authedRequest('POST', '/settings.json/ensure',
          body: 'default');
      await handler.router.call(ensureRequest);

      // Read — should still be 'existing'.
      final getRequest = _authedRequest('GET', '/settings.json');
      final getResponse = await handler.router.call(getRequest);
      expect(await getResponse.readAsString(), 'existing');
    });

    test('returns 403 for disallowed file name', () async {
      final request = _authedRequest('GET', '/../../etc/passwd');
      final response = await handler.router.call(request);
      expect(response.statusCode, 403);
    });

    test('supports URL-encoded file names', () async {
      // "Area Configuration.md" URL-encoded.
      final putRequest = _authedRequest(
          'PUT', '/Area%20Configuration.md',
          body: 'config data');
      final putResponse = await handler.router.call(putRequest);
      expect(putResponse.statusCode, 204);

      final getRequest =
          _authedRequest('GET', '/Area%20Configuration.md');
      final getResponse = await handler.router.call(getRequest);
      expect(await getResponse.readAsString(), 'config data');
    });

    test('isolates files per user', () async {
      // Write as testuser.
      final putRequest = _authedRequest('PUT', '/settings.json',
          body: 'user1 data');
      await handler.router.call(putRequest);

      // Read as different user.
      final request2 = Request(
        'GET',
        Uri.parse('http://localhost/settings.json'),
        context: {'username': 'otheruser'},
      );
      final response2 = await handler.router.call(request2);
      // otheruser's file doesn't exist yet.
      expect(await response2.readAsString(), '');
    });
  });
}
