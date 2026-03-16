import 'connection_interface.dart';
import 'web_connection_service.dart';

/// Creates the web connection service (WebSocket via server proxy).
MudConnectionService createConnectionService({
  String? serverUrl,
  String Function()? tokenProvider,
}) {
  assert(serverUrl != null, 'serverUrl required for web connection service');
  assert(
      tokenProvider != null, 'tokenProvider required for web connection service');
  return WebConnectionService(
    serverUrl: serverUrl!,
    tokenProvider: tokenProvider!,
  );
}
