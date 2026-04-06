import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/auth_middleware.dart';

/// Handles per-user audio file upload, listing, and streaming.
///
/// Audio files are stored in `{dataDir}/profiles/{username}/audio_cache/`.
class AudioHandler {
  final String _dataDir;

  /// Max upload size in bytes (default 10 MB).
  final int maxUploadBytes;

  static const _allowedExtensions = {'.mp3', '.ogg', '.wav', '.flac'};
  static final _nameRegex = RegExp(r'^[a-zA-Z0-9_.\- ]+$');

  static const _mimeTypes = {
    '.mp3': 'audio/mpeg',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
    '.flac': 'audio/flac',
  };

  AudioHandler(this._dataDir, {this.maxUploadBytes = 10 * 1024 * 1024});

  Router get router {
    final r = Router();
    r.get('/', _handleList);
    r.get('/<name|.*>', _handleStream);
    r.post('/<name|.*>', _handleUpload);
    return r;
  }

  String _audioDir(String username) {
    return p.join(_dataDir, 'profiles', username, 'audio_cache');
  }

  /// GET /api/audio/ — list audio files.
  Future<Response> _handleList(Request request) async {
    final username = getUsername(request);
    final dir = Directory(_audioDir(username));

    if (!await dir.exists()) {
      return Response.ok(jsonEncode(<String>[]),
          headers: {'content-type': 'application/json'});
    }

    final files = await dir.list().where((e) => e is File).map((e) {
      return p.basename(e.path);
    }).toList();

    return Response.ok(jsonEncode(files),
        headers: {'content-type': 'application/json'});
  }

  /// GET /api/audio/{name} — stream audio file.
  Future<Response> _handleStream(Request request, String name) async {
    name = Uri.decodeComponent(name);

    if (!_isValidName(name)) {
      return _jsonError(400, 'Invalid file name.');
    }

    final username = getUsername(request);
    final filePath = p.join(_audioDir(username), name);
    final file = File(filePath);

    if (!await file.exists()) {
      return Response.notFound(jsonEncode({'error': 'File not found.'}),
          headers: {'content-type': 'application/json'});
    }

    final ext = p.extension(name).toLowerCase();
    final contentType = _mimeTypes[ext] ?? 'application/octet-stream';
    final length = await file.length();

    return Response.ok(
      file.openRead(),
      headers: {
        'content-type': contentType,
        'content-length': length.toString(),
        'accept-ranges': 'bytes',
      },
    );
  }

  /// POST /api/audio/{name} — upload audio file.
  Future<Response> _handleUpload(Request request, String name) async {
    name = Uri.decodeComponent(name);

    if (!_isValidName(name)) {
      return _jsonError(400, 'Invalid file name.');
    }

    final ext = p.extension(name).toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      return _jsonError(400,
          'Invalid file type. Allowed: ${_allowedExtensions.join(', ')}');
    }

    // Check Content-Length if provided.
    final contentLength = request.contentLength;
    if (contentLength != null && contentLength > maxUploadBytes) {
      return _jsonError(413, 'File too large. Maximum ${maxUploadBytes ~/ (1024 * 1024)} MB.');
    }

    // Read body with size enforcement.
    final bytes = <int>[];
    try {
      await for (final chunk in request.read()) {
        bytes.addAll(chunk);
        if (bytes.length > maxUploadBytes) {
          return _jsonError(413,
              'File too large. Maximum ${maxUploadBytes ~/ (1024 * 1024)} MB.');
        }
      }
    } catch (_) {
      return _jsonError(400, 'Failed to read request body.');
    }

    final username = getUsername(request);
    final dir = Directory(_audioDir(username));
    await dir.create(recursive: true);

    final filePath = p.join(dir.path, name);
    await File(filePath).writeAsBytes(bytes);

    return Response(201,
        body: jsonEncode({'name': name, 'size': bytes.length}),
        headers: {'content-type': 'application/json'});
  }

  bool _isValidName(String name) {
    if (name.isEmpty) return false;
    if (name.contains('..') || name.contains('/') || name.contains('\\')) {
      return false;
    }
    if (name.contains('\x00')) return false;
    return _nameRegex.hasMatch(name);
  }

  Response _jsonError(int status, String message) {
    return Response(status,
        body: jsonEncode({'error': message}),
        headers: {'content-type': 'application/json'});
  }
}
