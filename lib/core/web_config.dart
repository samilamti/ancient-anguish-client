/// Configuration for the web client.
///
/// The server URL can be overridden at build time using:
///   `flutter build web --dart-define=SERVER_URL=https://my-server.com`
class WebConfig {
  WebConfig._();

  /// Base URL of the Dart Shelf server that provides auth, file storage,
  /// audio API, and WebSocket-to-TCP proxy.
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://localhost:8080',
  );
}
