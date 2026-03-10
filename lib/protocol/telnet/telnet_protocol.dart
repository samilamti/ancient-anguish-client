import 'dart:typed_data';

import 'telnet_events.dart';
import 'telnet_option.dart';

/// Telnet protocol state machine.
///
/// Processes raw bytes from a TCP socket and emits [TelnetEvent]s.
/// Handles IAC escaping, option negotiation detection, and subnegotiation
/// framing. The caller is responsible for sending appropriate responses.
///
/// ## Usage
/// ```dart
/// final protocol = TelnetProtocol();
/// socket.listen((bytes) {
///   final events = protocol.processBytes(Uint8List.fromList(bytes));
///   for (final event in events) {
///     // handle each event
///   }
/// });
/// ```
class TelnetProtocol {
  _TelnetState _state = _TelnetState.normal;
  int _negotiationCommand = 0;
  int _subnegOption = 0;
  final List<int> _subnegBuffer = [];
  final List<int> _dataBuffer = [];

  /// Processes a chunk of raw bytes from the socket.
  ///
  /// Returns a list of [TelnetEvent]s parsed from the input. Data between
  /// telnet commands is aggregated into [TelnetDataEvent]s.
  List<TelnetEvent> processBytes(Uint8List input) {
    final events = <TelnetEvent>[];

    for (var i = 0; i < input.length; i++) {
      final byte = input[i];

      switch (_state) {
        case _TelnetState.normal:
          if (byte == TelnetCmd.iac) {
            _state = _TelnetState.iac;
          } else {
            _dataBuffer.add(byte);
          }

        case _TelnetState.iac:
          switch (byte) {
            case TelnetCmd.iac:
              // Escaped 0xFF – emit as literal data byte.
              _dataBuffer.add(0xFF);
              _state = _TelnetState.normal;

            case TelnetCmd.will:
            case TelnetCmd.wont:
            case TelnetCmd.doOpt:
            case TelnetCmd.dont:
              _flushData(events);
              _negotiationCommand = byte;
              _state = _TelnetState.negotiation;

            case TelnetCmd.sb:
              _flushData(events);
              _state = _TelnetState.subnegOption;

            case TelnetCmd.ga:
            case TelnetCmd.eor:
            case TelnetCmd.nop:
            case TelnetCmd.ayt:
            case TelnetCmd.brk:
            case TelnetCmd.ip:
            case TelnetCmd.ao:
            case TelnetCmd.ec:
            case TelnetCmd.el:
              _flushData(events);
              events.add(TelnetCommandEvent(byte));
              _state = _TelnetState.normal;

            default:
              // Unknown command – ignore and return to normal.
              _state = _TelnetState.normal;
          }

        case _TelnetState.negotiation:
          events.add(TelnetNegotiationEvent(_negotiationCommand, byte));
          _state = _TelnetState.normal;

        case _TelnetState.subnegOption:
          _subnegOption = byte;
          _subnegBuffer.clear();
          _state = _TelnetState.subnegData;

        case _TelnetState.subnegData:
          if (byte == TelnetCmd.iac) {
            _state = _TelnetState.subnegIac;
          } else {
            _subnegBuffer.add(byte);
          }

        case _TelnetState.subnegIac:
          if (byte == TelnetCmd.se) {
            // End of subnegotiation.
            events.add(TelnetSubnegotiationEvent(
              _subnegOption,
              Uint8List.fromList(_subnegBuffer),
            ));
            _subnegBuffer.clear();
            _state = _TelnetState.normal;
          } else if (byte == TelnetCmd.iac) {
            // Escaped 0xFF inside subnegotiation.
            _subnegBuffer.add(0xFF);
            _state = _TelnetState.subnegData;
          } else {
            // Malformed – treat as end of subneg and re-process byte.
            events.add(TelnetSubnegotiationEvent(
              _subnegOption,
              Uint8List.fromList(_subnegBuffer),
            ));
            _subnegBuffer.clear();
            _state = _TelnetState.normal;
            // Re-process this byte in normal state.
            i--;
          }
      }
    }

    // Flush any remaining data.
    _flushData(events);
    return events;
  }

  /// Flushes accumulated data bytes as a [TelnetDataEvent].
  void _flushData(List<TelnetEvent> events) {
    if (_dataBuffer.isNotEmpty) {
      events.add(TelnetDataEvent(Uint8List.fromList(_dataBuffer)));
      _dataBuffer.clear();
    }
  }

  /// Resets the parser state (e.g., on reconnect).
  void reset() {
    _state = _TelnetState.normal;
    _dataBuffer.clear();
    _subnegBuffer.clear();
  }

  // ─── Static helpers for building telnet responses ───

  /// Builds a WILL response for the given option.
  static Uint8List buildWill(int option) =>
      Uint8List.fromList([TelnetCmd.iac, TelnetCmd.will, option]);

  /// Builds a WONT response for the given option.
  static Uint8List buildWont(int option) =>
      Uint8List.fromList([TelnetCmd.iac, TelnetCmd.wont, option]);

  /// Builds a DO response for the given option.
  static Uint8List buildDo(int option) =>
      Uint8List.fromList([TelnetCmd.iac, TelnetCmd.doOpt, option]);

  /// Builds a DONT response for the given option.
  static Uint8List buildDont(int option) =>
      Uint8List.fromList([TelnetCmd.iac, TelnetCmd.dont, option]);

  /// Builds a NAWS (window size) subnegotiation: IAC SB NAWS w1 w2 h1 h2 IAC SE.
  static Uint8List buildNaws(int columns, int rows) {
    final bytes = <int>[
      TelnetCmd.iac, TelnetCmd.sb, TelnetOpt.naws,
      (columns >> 8) & 0xFF, columns & 0xFF,
      (rows >> 8) & 0xFF, rows & 0xFF,
      TelnetCmd.iac, TelnetCmd.se,
    ];
    return Uint8List.fromList(bytes);
  }

  /// Builds a TTYPE IS subnegotiation: `IAC SB TTYPE IS <name> IAC SE`.
  static Uint8List buildTtypeIs(String terminalType) {
    final nameBytes = terminalType.codeUnits;
    final bytes = <int>[
      TelnetCmd.iac, TelnetCmd.sb, TelnetOpt.ttype,
      TtypeSub.is_,
      ...nameBytes,
      TelnetCmd.iac, TelnetCmd.se,
    ];
    return Uint8List.fromList(bytes);
  }
}

/// Internal parser states.
enum _TelnetState {
  /// Normal data pass-through.
  normal,

  /// Received IAC, waiting for command byte.
  iac,

  /// Received WILL/WONT/DO/DONT, waiting for option byte.
  negotiation,

  /// Received SB, waiting for option byte.
  subnegOption,

  /// Inside subnegotiation data, collecting bytes.
  subnegData,

  /// Received IAC inside subnegotiation, waiting for SE or escaped IAC.
  subnegIac,
}
