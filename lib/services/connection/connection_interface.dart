import 'dart:async';
import 'dart:typed_data';

import '../../models/connection_info.dart';
import '../../protocol/telnet/telnet_events.dart';

/// Abstract interface for MUD server connections.
///
/// Desktop: [TcpConnectionService] uses `dart:io` raw TCP sockets.
/// Web: will use WebSocket via the server proxy.
abstract class MudConnectionService {
  /// Stream of parsed telnet events (data, negotiations, commands).
  Stream<TelnetEvent> get events;

  /// Stream of connection status changes.
  Stream<ConnectionStatus> get statusStream;

  /// Stream of raw data bytes (before telnet parsing) for debugging.
  Stream<Uint8List> get rawData;

  /// Current connection status.
  ConnectionStatus get status;

  /// Whether the socket is currently connected.
  bool get isConnected;

  /// The current connection info, or null if not connected.
  ConnectionInfo? get connectionInfo;

  /// Connects to the specified MUD server.
  Future<void> connect([ConnectionInfo info]);

  /// Disconnects from the server.
  Future<void> disconnect();

  /// Sends a user command to the MUD, terminated with CR+LF.
  void sendCommand(String command);

  /// Sends raw bytes to the socket (for telnet negotiation responses).
  void sendBytes(Uint8List bytes);

  /// Disposes all resources.
  Future<void> dispose();
}
