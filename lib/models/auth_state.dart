/// Authentication state for the web client.
sealed class AuthState {
  const AuthState();
}

/// Not authenticated — show login/register screen.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Authentication request in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Successfully authenticated.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.token, required this.username});

  /// JWT token for API requests.
  final String token;

  /// Authenticated username.
  final String username;
}

/// Authentication failed with an error message.
class AuthError extends AuthState {
  const AuthError(this.message);

  /// Human-readable error description.
  final String message;
}
