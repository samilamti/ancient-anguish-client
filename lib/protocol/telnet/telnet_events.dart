import 'dart:typed_data';

/// Events emitted by the [TelnetProtocol] parser.
sealed class TelnetEvent {
  const TelnetEvent();
}

/// Raw data that should be displayed (after stripping telnet commands).
class TelnetDataEvent extends TelnetEvent {
  /// The data bytes (may contain ANSI escape sequences).
  final Uint8List data;

  const TelnetDataEvent(this.data);

  @override
  String toString() => 'TelnetDataEvent(${data.length} bytes)';
}

/// A telnet option negotiation (WILL/WONT/DO/DONT + option code).
class TelnetNegotiationEvent extends TelnetEvent {
  /// The command: WILL (251), WONT (252), DO (253), DONT (254).
  final int command;

  /// The option code (e.g., 1 for ECHO, 31 for NAWS).
  final int option;

  const TelnetNegotiationEvent(this.command, this.option);

  @override
  String toString() {
    final cmdName = switch (command) {
      251 => 'WILL',
      252 => 'WONT',
      253 => 'DO',
      254 => 'DONT',
      _ => 'CMD($command)',
    };
    return 'TelnetNegotiationEvent($cmdName, option=$option)';
  }
}

/// A telnet subnegotiation payload (SB ... SE).
class TelnetSubnegotiationEvent extends TelnetEvent {
  /// The option code this subnegotiation is for.
  final int option;

  /// The subnegotiation payload bytes (between SB <option> and IAC SE).
  final Uint8List data;

  const TelnetSubnegotiationEvent(this.option, this.data);

  @override
  String toString() =>
      'TelnetSubnegotiationEvent(option=$option, ${data.length} bytes)';
}

/// A simple telnet command (GA, EOR, NOP, AYT, etc.).
class TelnetCommandEvent extends TelnetEvent {
  /// The command byte.
  final int command;

  const TelnetCommandEvent(this.command);

  @override
  String toString() => 'TelnetCommandEvent($command)';
}
