import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/web_config.dart';
import '../models/auth_state.dart';

/// Notifier managing web authentication state.
///
/// Handles login and registration via the Dart Shelf server's auth API.
/// Stores the JWT token in memory (no persistent token storage for MVP).
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthUnauthenticated();

  /// The current JWT token, or null if not authenticated.
  String? get token {
    final s = state;
    return s is AuthAuthenticated ? s.token : null;
  }

  /// The current username, or null if not authenticated.
  String? get username {
    final s = state;
    return s is AuthAuthenticated ? s.username : null;
  }

  /// Attempts to log in with the given credentials.
  Future<void> login(String username, String password) async {
    state = const AuthLoading();
    try {
      final response = await http.post(
        Uri.parse('${WebConfig.serverUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        state = AuthAuthenticated(
          token: body['token'] as String,
          username: body['username'] as String,
        );
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        state = AuthError(body['error'] as String? ?? 'Login failed');
      }
    } catch (e) {
      debugPrint('AuthNotifier.login: $e');
      state = AuthError('Connection error: $e');
    }
  }

  /// Attempts to register a new account.
  Future<void> register(String username, String password) async {
    state = const AuthLoading();
    try {
      final response = await http.post(
        Uri.parse('${WebConfig.serverUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        state = AuthAuthenticated(
          token: body['token'] as String,
          username: body['username'] as String,
        );
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        state = AuthError(body['error'] as String? ?? 'Registration failed');
      }
    } catch (e) {
      debugPrint('AuthNotifier.register: $e');
      state = AuthError('Connection error: $e');
    }
  }

  /// Logs out and returns to unauthenticated state.
  void logout() {
    state = const AuthUnauthenticated();
  }
}

/// Provider for the auth notifier.
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
