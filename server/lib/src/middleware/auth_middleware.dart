import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../auth/jwt_service.dart';

/// Creates middleware that verifies JWT tokens.
///
/// Checks `Authorization: Bearer <token>` header first, then falls back to
/// `?token=<jwt>` query parameter (needed for WebSocket upgrade since browsers
/// cannot set custom headers on WebSocket connections).
///
/// On success, sets `request.context['username']` for downstream handlers.
Middleware createAuthMiddleware(JwtService jwtService) {
  return (Handler innerHandler) {
    return (Request request) {
      // Try Authorization header first.
      String? token;
      final authHeader = request.headers['authorization'];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7);
      }

      // Fall back to query parameter.
      token ??= request.requestedUri.queryParameters['token'];

      if (token == null || token.isEmpty) {
        return Response(401,
            body: jsonEncode({'error': 'Authentication required.'}),
            headers: {'content-type': 'application/json'});
      }

      final username = jwtService.verify(token);
      if (username == null) {
        return Response(401,
            body: jsonEncode({'error': 'Invalid or expired token.'}),
            headers: {'content-type': 'application/json'});
      }

      final updatedRequest = request.change(context: {'username': username});
      return innerHandler(updatedRequest);
    };
  };
}

/// Extracts the authenticated username from the request context.
String getUsername(Request request) => request.context['username'] as String;
