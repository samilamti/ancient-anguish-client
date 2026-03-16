import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/auth_middleware.dart';
import 'file_whitelist.dart';

/// Handles per-user config file CRUD operations.
///
/// All file paths resolve to `{dataDir}/profiles/{username}/{name}`.
class FileHandler {
  final String _dataDir;

  /// Max body size for file writes (default 1 MB).
  final int maxBodyBytes;

  FileHandler(this._dataDir, {this.maxBodyBytes = 1024 * 1024});

  Router get router {
    final r = Router();

    // The <name> parameter is a catch-all to support paths like "logs/session_xxx.txt".
    // shelf_router uses <name|.*> for catch-all.
    r.get('/<name|.*>/lines', _handleReadLines);
    r.get('/<name|.*>/meta', _handleMeta);
    r.get('/<name|.*>', _handleRead);
    r.put('/<name|.*>', _handleWrite);
    r.post('/<name|.*>/append', _handleAppend);
    r.post('/<name|.*>/ensure', _handleEnsure);

    return r;
  }

  String _userFilePath(String username, String name) {
    return p.join(_dataDir, 'profiles', username, name);
  }

  Response _forbidden(String name) {
    return Response(403,
        body: jsonEncode({'error': 'File name not allowed: $name'}),
        headers: {'content-type': 'application/json'});
  }

  /// GET /api/files/{name} — read entire file.
  /// Returns empty string if file doesn't exist (matching StorageService behavior).
  Future<Response> _handleRead(Request request, String name) async {
    name = Uri.decodeComponent(name);
    final validated = FileWhitelist.validate(name);
    if (validated == null) return _forbidden(name);

    final username = getUsername(request);
    final filePath = _userFilePath(username, validated);
    final file = File(filePath);

    if (await file.exists()) {
      final contents = await file.readAsString();
      return Response.ok(contents);
    }
    return Response.ok('');
  }

  /// GET /api/files/{name}/lines — read file as JSON array of lines.
  Future<Response> _handleReadLines(Request request, String name) async {
    name = Uri.decodeComponent(name);
    final validated = FileWhitelist.validate(name);
    if (validated == null) return _forbidden(name);

    final username = getUsername(request);
    final filePath = _userFilePath(username, validated);
    final file = File(filePath);

    if (await file.exists()) {
      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return Response.ok(jsonEncode(<String>[]),
            headers: {'content-type': 'application/json'});
      }
      final lines = contents.split('\n');
      return Response.ok(jsonEncode(lines),
          headers: {'content-type': 'application/json'});
    }
    return Response.ok(jsonEncode(<String>[]),
        headers: {'content-type': 'application/json'});
  }

  /// PUT /api/files/{name} — write file (replaces contents).
  Future<Response> _handleWrite(Request request, String name) async {
    name = Uri.decodeComponent(name);
    final validated = FileWhitelist.validate(name);
    if (validated == null) return _forbidden(name);

    final body = await _readBody(request);
    if (body == null) {
      return Response(413,
          body: jsonEncode({'error': 'Body too large.'}),
          headers: {'content-type': 'application/json'});
    }

    final username = getUsername(request);
    final filePath = _userFilePath(username, validated);
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(body);

    return Response(204);
  }

  /// POST /api/files/{name}/append — append text to file.
  Future<Response> _handleAppend(Request request, String name) async {
    name = Uri.decodeComponent(name);
    final validated = FileWhitelist.validate(name);
    if (validated == null) return _forbidden(name);

    final body = await _readBody(request);
    if (body == null) {
      return Response(413,
          body: jsonEncode({'error': 'Body too large.'}),
          headers: {'content-type': 'application/json'});
    }

    final username = getUsername(request);
    final filePath = _userFilePath(username, validated);
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(body, mode: FileMode.append);

    return Response(204);
  }

  /// POST /api/files/{name}/ensure — ensure file exists with optional default content.
  Future<Response> _handleEnsure(Request request, String name) async {
    name = Uri.decodeComponent(name);
    final validated = FileWhitelist.validate(name);
    if (validated == null) return _forbidden(name);

    final username = getUsername(request);
    final filePath = _userFilePath(username, validated);
    final file = File(filePath);

    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      final body = await _readBody(request) ?? '';
      await file.writeAsString(body);
    }

    return Response(204);
  }

  /// GET /api/files/{name}/meta — check existence and length.
  Future<Response> _handleMeta(Request request, String name) async {
    name = Uri.decodeComponent(name);
    final validated = FileWhitelist.validate(name);
    if (validated == null) return _forbidden(name);

    final username = getUsername(request);
    final filePath = _userFilePath(username, validated);
    final file = File(filePath);
    final exists = await file.exists();
    final length = exists ? await file.length() : 0;

    return Response.ok('', headers: {
      'X-File-Exists': exists.toString(),
      'X-File-Length': length.toString(),
    });
  }

  /// Reads the request body with size limit enforcement.
  /// Returns `null` if the body exceeds [maxBodyBytes].
  Future<String?> _readBody(Request request) async {
    // Check Content-Length header if present.
    final contentLength = request.contentLength;
    if (contentLength != null && contentLength > maxBodyBytes) {
      return null;
    }

    final bytes = await request.read().fold<List<int>>(
      <int>[],
      (buffer, chunk) {
        buffer.addAll(chunk);
        if (buffer.length > maxBodyBytes) {
          throw const _BodyTooLargeException();
        }
        return buffer;
      },
    );
    return utf8.decode(bytes);
  }
}

class _BodyTooLargeException implements Exception {
  const _BodyTooLargeException();
}
