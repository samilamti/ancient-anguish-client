import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Creates and verifies JWT tokens for user authentication.
class JwtService {
  final String secret;
  final Duration expiry;

  JwtService(this.secret, {this.expiry = const Duration(days: 7)});

  /// Creates a signed JWT for [username].
  String createToken(String username) {
    final jwt = JWT(
      {
        'sub': username,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
    );
    return jwt.sign(
      SecretKey(secret),
      expiresIn: expiry,
    );
  }

  /// Verifies [token] and returns the username, or `null` if invalid/expired.
  String? verify(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(secret));
      final payload = jwt.payload as Map<String, dynamic>;
      return payload['sub'] as String?;
    } on JWTExpiredException {
      return null;
    } on JWTException {
      return null;
    }
  }
}
