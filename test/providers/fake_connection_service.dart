import 'dart:async';
import 'dart:typed_data';

import 'package:ancient_anguish_client/models/connection_info.dart';
import 'package:ancient_anguish_client/protocol/telnet/telnet_events.dart';
import 'package:ancient_anguish_client/services/connection/connection_interface.dart';

/// A [MudConnectionService] that feeds the terminal buffer without opening a
/// socket. Shared rather than copied per test file: every change to the
/// connection interface otherwise means hunting down each duplicate fake, and
/// the compiler only complains about whichever one you happen to compile.
class FakeConnectionService implements MudConnectionService {
  final _events = StreamController<TelnetEvent>.broadcast();
  final _status = StreamController<ConnectionStatus>.broadcast();
  final _rawData = StreamController<Uint8List>.broadcast();

  /// Commands the code under test asked to send.
  final List<String> sentCommands = [];

  void emit(TelnetEvent event) => _events.add(event);

  /// Feeds [lines] as one CRLF-terminated chunk, the way the MUD sends them.
  void emitLines(Iterable<String> lines) => emit(
        TelnetDataEvent(
          Uint8List.fromList('${lines.join('\r\n')}\r\n'.codeUnits),
        ),
      );

  /// Feeds [text] verbatim — no terminator added. AA ends a command's output
  /// with a prompt carrying no newline, GA or EOR, so anything that depends on
  /// that trailing partial line has to be fed this way rather than via
  /// [emitLines].
  void emitChunk(String text) =>
      emit(TelnetDataEvent(Uint8List.fromList(text.codeUnits)));

  @override
  Stream<TelnetEvent> get events => _events.stream;

  @override
  Stream<ConnectionStatus> get statusStream => _status.stream;

  @override
  Stream<Uint8List> get rawData => _rawData.stream;

  @override
  ConnectionStatus get status => ConnectionStatus.connected;

  @override
  bool get isConnected => true;

  @override
  ConnectionInfo? get connectionInfo => ConnectionInfo.ancientAnguish;

  @override
  Future<void> connect([ConnectionInfo? info]) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> reconnect([ConnectionInfo? info]) async {}

  @override
  void sendCommand(String command) => sentCommands.add(command);

  @override
  void sendBytes(Uint8List bytes) {}

  @override
  void checkAlive() {}

  @override
  Future<void> dispose() async {
    await _events.close();
    await _status.close();
    await _rawData.close();
  }
}
