import '../core/constants.dart';

/// Connection profile for a MUD server.
class ConnectionInfo {
  final String name;
  final String host;
  final int port;

  const ConnectionInfo({
    required this.name,
    required this.host,
    required this.port,
  });

  /// Default Ancient Anguish connection.
  static const ConnectionInfo ancientAnguish = ConnectionInfo(
    name: AaDefaults.name,
    host: AaDefaults.host,
    port: AaDefaults.port,
  );

  @override
  String toString() => '$name ($host:$port)';
}

/// Represents the state of a connection.
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}
