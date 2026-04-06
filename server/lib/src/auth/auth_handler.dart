import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'jwt_service.dart';
import 'user_store.dart';

/// Handles user registration and login.
class AuthHandler {
  final UserStore _userStore;
  final JwtService _jwtService;

  AuthHandler(this._userStore, this._jwtService);

  Router get router {
    final r = Router();
    r.post('/register', _handleRegister);
    r.post('/login', _handleLogin);
    return r;
  }

  Future<Response> _handleRegister(Request request) async {
    final body = await _parseJsonBody(request);
    if (body == null) {
      return _jsonError(400, 'Invalid JSON body.');
    }

    final username = body['username'] as String?;
    final password = body['password'] as String?;

    if (username == null || password == null) {
      return _jsonError(400, 'Missing username or password.');
    }

    final error = await _userStore.register(username, password);
    if (error != null) {
      // 409 for duplicate, 400 for validation.
      final status = error.contains('already taken') ? 409 : 400;
      return _jsonError(status, error);
    }

    final token = _jwtService.createToken(username);
    return Response(201,
        body: jsonEncode({'token': token, 'username': username}),
        headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleLogin(Request request) async {
    final body = await _parseJsonBody(request);
    if (body == null) {
      return _jsonError(400, 'Invalid JSON body.');
    }

    final username = body['username'] as String?;
    final password = body['password'] as String?;

    if (username == null || password == null) {
      return _jsonError(400, 'Missing username or password.');
    }

    final canonical = await _userStore.authenticate(username, password);
    if (canonical == null) {
      return _jsonError(401, 'Invalid username or password.');
    }

    final token = _jwtService.createToken(canonical);
    return Response.ok(
        jsonEncode({'token': token, 'username': canonical}),
        headers: {'content-type': 'application/json'});
  }

  Future<Map<String, dynamic>?> _parseJsonBody(Request request) async {
    try {
      final text = await request.readAsString();
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Response _jsonError(int status, String message) {
    return Response(status,
        body: jsonEncode({'error': message}),
        headers: {'content-type': 'application/json'});
  }
}
