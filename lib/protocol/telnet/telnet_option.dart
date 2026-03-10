/// Telnet protocol command and option constants (RFC 854, RFC 855).
library;

/// Telnet command bytes.
class TelnetCmd {
  TelnetCmd._();

  /// Interpret As Command – marks the start of a telnet command sequence.
  static const int iac = 255;

  /// Refuse to perform / continue performing the indicated option.
  static const int dont = 254;

  /// Request that the other party perform the indicated option.
  static const int doOpt = 253;

  /// Refusal to perform the indicated option.
  static const int wont = 252;

  /// Agreement to perform the indicated option.
  static const int will = 251;

  /// Subnegotiation begin.
  static const int sb = 250;

  /// Go Ahead signal.
  static const int ga = 249;

  /// Erase Line.
  static const int el = 248;

  /// Erase Character.
  static const int ec = 247;

  /// Are You There.
  static const int ayt = 246;

  /// Abort Output.
  static const int ao = 245;

  /// Interrupt Process.
  static const int ip = 244;

  /// Break.
  static const int brk = 243;

  /// No Operation.
  static const int nop = 241;

  /// Subnegotiation End.
  static const int se = 240;

  /// End of Record (RFC 885).
  static const int eor = 239;
}

/// Telnet option codes.
class TelnetOpt {
  TelnetOpt._();

  /// Echo (RFC 857).
  static const int echo = 1;

  /// Suppress Go-Ahead (RFC 858).
  static const int sga = 3;

  /// Terminal Type (RFC 1091).
  static const int ttype = 24;

  /// End of Record (RFC 885).
  static const int eor = 25;

  /// Negotiate About Window Size (RFC 1073).
  static const int naws = 31;

  /// Linemode (RFC 1184).
  static const int linemode = 34;

  /// MUD Client Compression Protocol v2.
  static const int mccp2 = 86;

  /// MUD Client Compression Protocol v3.
  static const int mccp3 = 87;

  /// Generic MUD Communication Protocol (GMCP / ATCP2).
  static const int gmcp = 201;
}

/// Subnegotiation sub-commands for TTYPE.
class TtypeSub {
  TtypeSub._();

  /// IS – response to a SEND request.
  static const int is_ = 0;

  /// SEND – request terminal type.
  static const int send = 1;
}
