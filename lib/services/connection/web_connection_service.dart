import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/connection_info.dart';
import '../../protocol/telnet/telnet_events.dart';
import '../../protocol/telnet/telnet_protocol.dart';
import 'connection_interface.dart';

/// Web implementation of [MudConnectionService] that connects to the MUD
/// through the server's WebSocket-to-TCP proxy.
///
/// The server relays raw bytes between the WebSocket and the MUD's TCP socket.
/// Telnet protocol parsing happens client-side using the same [TelnetProtocol]
/// as the desktop client.
class WebConnectionService implements MudConnectionService {
  WebConnectionService({
    required String serverUrl,
    required String Function() tokenProvider,
  })  : _serverUrl = serverUrl,
        _tokenProvider = tokenProvider;

  final String _serverUrl;
  final String Function() _tokenProvider;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final TelnetProtocol _telnet = TelnetProtocol();

  final _eventController = StreamController<TelnetEvent>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _rawDataController = StreamController<Uint8List>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionInfo? _connectionInfo;

  @override
  Stream<TelnetEvent> get events => _eventController.stream;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  Stream<Uint8List> get rawData => _rawDataController.stream;

  @override
  ConnectionStatus get status => _status;

  @override
  bool get isConnected => _status == ConnectionStatus.connected;

  @override
  ConnectionInfo? get connectionInfo => _connectionInfo;

  void _setStatus(ConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  @override
  Future<void> connect([ConnectionInfo? info]) async {
    if (_status == ConnectionStatus.connecting ||
        _status == ConnectionStatus.connected) {
      return;
    }

    _connectionInfo = info ?? ConnectionInfo.ancientAnguish;
    _setStatus(ConnectionStatus.connecting);

    try {
      // Build WebSocket URL with auth token as query param.
      final wsScheme = _serverUrl.startsWith('https') ? 'wss' : 'ws';
      final hostPart = _serverUrl
          .replaceFirst('https://', '')
          .replaceFirst('http://', '');
      final token = _tokenProvider();
      final wsUrl = '$wsScheme://$hostPart/ws/mud?token=$token';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;
      _setStatus(ConnectionStatus.connected);

      _subscription = _channel!.stream.listen(
        (data) {
          Uint8List bytes;
          if (data is List<int>) {
            bytes = Uint8List.fromList(data);
          } else if (data is String) {
            bytes = Uint8List.fromList(utf8.encode(data));
          } else {
            return;
          }

          _rawDataController.add(bytes);

          // Parse through telnet protocol — emits TelnetEvents.
          final events = _telnet.processBytes(bytes);
          for (final event in events) {
            _eventController.add(event);
          }
        },
        onError: (Object error) {
          debugPrint('WebConnectionService: WebSocket error: $error');
          _setStatus(ConnectionStatus.error);
          _cleanup();
        },
        onDone: () {
          debugPrint('WebConnectionService: WebSocket closed');
          _setStatus(ConnectionStatus.disconnected);
          _cleanup();
        },
      );
    } catch (e) {
      debugPrint('WebConnectionService.connect: $e');
      _setStatus(ConnectionStatus.error);
      _cleanup();
    }
  }

  @override
  Future<void> disconnect() async {
    if (_status == ConnectionStatus.disconnected) return;
    _setStatus(ConnectionStatus.disconnecting);
    await _cleanup();
    _setStatus(ConnectionStatus.disconnected);
  }

  @override
  void sendCommand(String command) {
    if (!isConnected || _channel == null) return;
    final bytes = utf8.encode('$command\r\n');
    _channel!.sink.add(bytes);
  }

  @override
  void sendBytes(Uint8List bytes) {
    if (!isConnected || _channel == null) return;
    _channel!.sink.add(bytes);
  }

  Future<void> _cleanup() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  @override
  Future<void> dispose() async {
    await _cleanup();
    await _eventController.close();
    await _statusController.close();
    await _rawDataController.close();
  }
}
