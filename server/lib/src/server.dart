import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth/auth_handler.dart';
import 'auth/jwt_service.dart';
import 'auth/user_store.dart';
import 'audio/audio_handler.dart';
import 'config.dart';
import 'files/file_handler.dart';
import 'middleware/auth_middleware.dart';
import 'middleware/cors_middleware.dart';
import 'proxy/mud_proxy_handler.dart';

/// Builds the shelf [Handler] with all routes and middleware.
///
/// Call once at startup; the returned handler is passed to `shelf_io.serve`.
Future<Handler> buildServer(ServerConfig config) async {
  final userStore = UserStore(config.dataDir);
  await userStore.load();

  final jwtService = JwtService(config.jwtSecret, expiry: config.jwtExpiry);
  final authHandler = AuthHandler(userStore, jwtService);
  final fileHandler = FileHandler(config.dataDir,
      maxBodyBytes: config.maxFileBodyBytes);
  final audioHandler = AudioHandler(config.dataDir,
      maxUploadBytes: config.maxAudioBodyBytes);
  final mudProxy = MudProxyHandler(config);
  final authMw = createAuthMiddleware(jwtService);

  final router = Router()
    // Public auth endpoints.
    ..mount('/api/auth/', authHandler.router.call)
    // Protected file API.
    ..mount('/api/files/', (Request request) {
      return const Pipeline()
          .addMiddleware(authMw)
          .addHandler(fileHandler.router.call)(request);
    })
    // Protected audio API.
    ..mount('/api/audio/', (Request request) {
      return const Pipeline()
          .addMiddleware(authMw)
          .addHandler(audioHandler.router.call)(request);
    })
    // Protected WebSocket proxy.
    ..get('/ws/mud', const Pipeline()
        .addMiddleware(authMw)
        .addHandler(mudProxy.handle));

  return const Pipeline()
      .addMiddleware(createCorsMiddleware(config.corsOrigins))
      .addMiddleware(logRequests())
      .addHandler(router.call);
}
