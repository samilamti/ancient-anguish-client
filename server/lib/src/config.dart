/// Server configuration.
class ServerConfig {
  final int port;
  final String dataDir;
  final String jwtSecret;
  final List<String> corsOrigins;
  final String mudHost;
  final int mudPort;
  final Duration jwtExpiry;

  /// Max body size for config file writes (1 MB).
  final int maxFileBodyBytes;

  /// Max body size for audio uploads (10 MB).
  final int maxAudioBodyBytes;

  const ServerConfig({
    this.port = 8080,
    this.dataDir = './data',
    required this.jwtSecret,
    this.corsOrigins = const ['*'],
    this.mudHost = 'ancient.anguish.org',
    this.mudPort = 2222,
    this.jwtExpiry = const Duration(days: 7),
    this.maxFileBodyBytes = 1024 * 1024, // 1 MB
    this.maxAudioBodyBytes = 10 * 1024 * 1024, // 10 MB
  });
}
