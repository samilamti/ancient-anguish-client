/// Application-wide constants for the Ancient Anguish MUD Client.
library;

/// Default connection settings for Ancient Anguish.
class AaDefaults {
  AaDefaults._();

  static const String host = 'ancient.anguish.org';
  static const int port = 2222;
  static const String name = 'Ancient Anguish';

  /// The terminal type string sent during telnet negotiation.
  static const String terminalType = 'ANCIENT-ANGUISH-CLIENT';

  /// Default prompt regex for AA: "HP/MAXHP:SP/MAXSP>"
  static const String promptPattern = r'(\d+)/(\d+):(\d+)/(\d+)>';

  /// Extended CLIENT line regex for coordinate/player data.
  static const String clientLinePattern =
      r'CLIENT:X:(-?\d+):Y:(-?\d+):(\w+):(\w+):(\d+):(\d+)';
}

/// Terminal display defaults.
class TerminalDefaults {
  TerminalDefaults._();

  static const double fontSize = 14.0;
  static const double mobileFontSize = 12.0;
  static const String fontFamily = 'JetBrainsMono';

  /// Default terminal columns/rows for NAWS negotiation.
  static const int columns = 80;
  static const int rows = 24;
}

/// Audio defaults.
class AudioDefaults {
  AudioDefaults._();

  static const double masterVolume = 0.7;

  /// Default fade-in duration in milliseconds.
  static const int fadeInMs = 2000;

  /// Default fade-out duration in milliseconds.
  static const int fadeOutMs = 2000;

  /// Delay before starting town music, in milliseconds.
  /// Prevents rapid switching when players enter/leave towns through portals.
  static const int townDelayMs = 5000;
}
