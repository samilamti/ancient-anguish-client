import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../models/connection_info.dart';
import '../../protocol/telnet/telnet_events.dart';
import '../../protocol/telnet/telnet_option.dart';
import '../../protocol/telnet/telnet_protocol.dart';
import 'connection_interface.dart';

/// Manages the TCP socket connection to a MUD server.
///
/// Handles:
/// - Socket lifecycle (connect, disconnect, reconnect).
/// - Telnet option negotiation (NAWS, TTYPE, SGA, ECHO).
/// - Emitting parsed [TelnetEvent]s to listeners.
/// - Sending user commands with CR+LF termination.
class TcpConnectionService implements MudConnectionService {
  /// How often to probe the socket with a telnet NOP while connected.
  ///
  /// Without this, an idle client never writes to the socket, so the OS
  /// never notices a half-open connection (WiFi dropped, laptop slept,
  /// iOS suspended the app). The NOP forces a TCP send; if the link is
  /// broken, the stream's `onError`/`onDone` fires within the retransmit
  /// window and the UI flips to disconnected.
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  Socket? _socket;
  final TelnetProtocol _telnet = TelnetProtocol();
  StreamSubscription<Uint8List>? _subscription;
  Timer? _heartbeatTimer;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionInfo? _connectionInfo;

  // Event streams.
  final _eventController = StreamController<TelnetEvent>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _rawDataController = StreamController<Uint8List>.broadcast();

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

  @override
  Future<void> connect([
    ConnectionInfo info = ConnectionInfo.ancientAnguish,
  ]) async {
    if (_status == ConnectionStatus.connecting ||
        _status == ConnectionStatus.connected) {
      return;
    }

    _connectionInfo = info;
    _setStatus(ConnectionStatus.connecting);
    _telnet.reset();

    // Cancel any stale subscription from a previous connection attempt.
    await _subscription?.cancel();
    _subscription = null;

    try {
      _socket = await Socket.connect(
        info.host,
        info.port,
        timeout: const Duration(seconds: 15),
      );

      _setStatus(ConnectionStatus.connected);

      _subscription = _socket!.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _startHeartbeat();
    } on SocketException catch (e) {
      debugPrint('ConnectionService.connect: ${e.message}');
      _setStatus(ConnectionStatus.error);
      _eventController.addError('Connection failed: ${e.message}');
    } on TimeoutException catch (e) {
      debugPrint('ConnectionService.connect: timeout $e');
      _setStatus(ConnectionStatus.error);
      _eventController.addError('Connection timed out to ${info.host}:${info.port}');
    }
  }

  @override
  Future<void> disconnect() async {
    if (_status == ConnectionStatus.disconnected ||
        _status == ConnectionStatus.disconnecting) {
      return;
    }

    _setStatus(ConnectionStatus.disconnecting);

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    try {
      _socket?.destroy();
    } catch (e) {
      debugPrint('ConnectionService.disconnect error: $e');
    }
    _socket = null;

    _setStatus(ConnectionStatus.disconnected);
  }

  @override
  void sendCommand(String command) {
    if (!isConnected || _socket == null) return;
    try {
      _socket!.add(utf8.encode('$command\r\n'));
    } on SocketException catch (e) {
      debugPrint('ConnectionService.sendCommand: ${e.message}');
      _eventController.addError('Send failed: ${e.message}');
    }
  }

  @override
  void sendBytes(Uint8List bytes) {
    if (!isConnected || _socket == null) return;
    try {
      _socket!.add(bytes);
    } on SocketException catch (e) {
      debugPrint('ConnectionService.sendBytes: ${e.message}');
      _eventController.addError('Send failed: ${e.message}');
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _eventController.close();
    await _statusController.close();
    await _rawDataController.close();
  }

  // ── Private handlers ──

  void _onData(Uint8List data) {
    _rawDataController.add(data);

    final events = _telnet.processBytes(data);
    for (final event in events) {
      // Auto-handle telnet negotiations.
      if (event is TelnetNegotiationEvent) {
        _handleNegotiation(event);
      } else if (event is TelnetSubnegotiationEvent) {
        _handleSubnegotiation(event);
      }
      _eventController.add(event);
    }
  }

  void _onError(Object error) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _setStatus(ConnectionStatus.error);
    _eventController.addError('Socket error: $error');
  }

  void _onDone() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription = null;
    _socket = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => _sendHeartbeat(),
    );
  }

  /// Writes a telnet NOP (`IAC NOP`, bytes `0xFF 0xF1`) to keep the pipe
  /// flowing. The server ignores NOP; we ignore failures here because any
  /// actual socket error is routed via `_onError`/`_onDone`.
  void _sendHeartbeat() {
    if (_status != ConnectionStatus.connected || _socket == null) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      return;
    }
    try {
      _socket!.add(Uint8List.fromList([TelnetCmd.iac, TelnetCmd.nop]));
    } catch (e) {
      debugPrint('ConnectionService._sendHeartbeat: $e');
      _onError(e);
    }
  }

  @override
  void checkAlive() {
    if (_status == ConnectionStatus.connected) {
      _sendHeartbeat();
    }
  }

  void _setStatus(ConnectionStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Handles telnet option negotiations automatically.
  void _handleNegotiation(TelnetNegotiationEvent event) {
    switch (event.command) {
      case TelnetCmd.doOpt:
        // Server asks us to DO something.
        switch (event.option) {
          case TelnetOpt.naws:
            sendBytes(TelnetProtocol.buildWill(TelnetOpt.naws));
            sendBytes(TelnetProtocol.buildNaws(
              TerminalDefaults.columns,
              TerminalDefaults.rows,
            ));
          case TelnetOpt.ttype:
            sendBytes(TelnetProtocol.buildWill(TelnetOpt.ttype));
          case TelnetOpt.sga:
            sendBytes(TelnetProtocol.buildWill(TelnetOpt.sga));
          default:
            // Refuse unknown DO requests.
            sendBytes(TelnetProtocol.buildWont(event.option));
        }

      case TelnetCmd.will:
        // Server says it WILL do something.
        switch (event.option) {
          case TelnetOpt.sga:
            sendBytes(TelnetProtocol.buildDo(TelnetOpt.sga));
          case TelnetOpt.echo:
            // Server will echo – we should hide local echo.
            sendBytes(TelnetProtocol.buildDo(TelnetOpt.echo));
          default:
            // Accept or refuse.
            sendBytes(TelnetProtocol.buildDont(event.option));
        }

      case TelnetCmd.wont:
        // Acknowledged.
        break;

      case TelnetCmd.dont:
        // Acknowledged – send WONT.
        sendBytes(TelnetProtocol.buildWont(event.option));
    }
  }

  /// Handles telnet subnegotiations.
  void _handleSubnegotiation(TelnetSubnegotiationEvent event) {
    switch (event.option) {
      case TelnetOpt.ttype:
        // Server is asking for our terminal type.
        if (event.data.isNotEmpty && event.data[0] == TtypeSub.send) {
          sendBytes(
            TelnetProtocol.buildTtypeIs(AaDefaults.terminalType),
          );
        }
    }
  }
}
