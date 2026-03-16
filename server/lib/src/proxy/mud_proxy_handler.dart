import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../middleware/auth_middleware.dart';

/// Handles WebSocket-to-TCP proxy connections to the MUD server.
///
/// Each WebSocket connection opens a dedicated TCP socket to the MUD.
/// Raw bytes are relayed bidirectionally without any parsing.
class MudProxyHandler {
  final ServerConfig _config;

  MudProxyHandler(this._config);

  /// Shelf handler that upgrades to WebSocket and starts the TCP relay.
  FutureOr<Response> handle(Request request) {
    final username = getUsername(request);

    return webSocketHandler((WebSocketChannel webSocket) async {
      Socket? tcpSocket;
      StreamSubscription<List<int>>? tcpSub;
      StreamSubscription? wsSub;
      var closed = false;

      void cleanup() {
        if (closed) return;
        closed = true;
        tcpSub?.cancel();
        wsSub?.cancel();
        tcpSocket?.destroy();
        // Don't call webSocket.sink.close() if the WS initiated the close.
        try {
          webSocket.sink.close();
        } catch (_) {}
        print('MUD proxy closed for user: $username');
      }

      try {
        // Connect to MUD.
        tcpSocket = await Socket.connect(
          _config.mudHost,
          _config.mudPort,
          timeout: const Duration(seconds: 15),
        );
        print('MUD proxy connected for user: $username → '
            '${_config.mudHost}:${_config.mudPort}');

        // TCP → WebSocket: forward raw bytes as binary frames.
        tcpSub = tcpSocket.listen(
          (data) {
            if (!closed) {
              try {
                webSocket.sink.add(data);
              } catch (_) {
                cleanup();
              }
            }
          },
          onError: (Object error) {
            print('MUD proxy TCP error for $username: $error');
            cleanup();
          },
          onDone: () {
            print('MUD proxy TCP closed for $username');
            cleanup();
          },
        );

        // WebSocket → TCP: forward binary frame payload as raw bytes.
        wsSub = webSocket.stream.listen(
          (message) {
            if (!closed) {
              try {
                if (message is List<int>) {
                  tcpSocket?.add(message);
                } else if (message is String) {
                  // Text frames: encode as UTF-8 bytes.
                  tcpSocket?.add(message.codeUnits);
                }
              } catch (_) {
                cleanup();
              }
            }
          },
          onError: (Object error) {
            print('MUD proxy WS error for $username: $error');
            cleanup();
          },
          onDone: () {
            print('MUD proxy WS closed for $username');
            cleanup();
          },
        );
      } catch (e) {
        print('MUD proxy connection failed for $username: $e');
        try {
          webSocket.sink.close(4000, 'Failed to connect to MUD server.');
        } catch (_) {}
        cleanup();
      }
    })(request);
  }
}
