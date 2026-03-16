import 'connection_interface.dart';
import 'connection_service.dart';

/// Creates the desktop connection service (raw TCP socket).
MudConnectionService createConnectionService({
  String? serverUrl,
  String Function()? tokenProvider,
}) {
  return TcpConnectionService();
}
