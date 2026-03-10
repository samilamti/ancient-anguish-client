import 'package:flutter/foundation.dart';

import '../../models/game_state.dart';

/// Parses Ancient Anguish prompt lines to extract structured game data.
///
/// AA prompts come in two forms:
///
/// 1. **Basic prompt**: `125/125:80/80>`
///    Provides HP/MaxHP and SP/MaxSP.
///
/// 2. **Extended CLIENT line**: `CLIENT:X:5:Y:12:Gandalf:fighter:1500:25000`
///    Provides coordinates, player name, class, coins, and XP.
///    Requires the player to set a custom prompt in-game:
///    `set prompt |HP|/|MAXHP|:|SP|/|MAXSP|>\n CLIENT:X:|XCOORD|:Y:|YCOORD|:|NAME|:|CLASS|:|COINS|:|XP|`
///
/// The parser maintains the last known game state and updates it incrementally
/// as new prompt data arrives.
class PromptParser {
  GameState _lastState = GameState.initial;

  /// The most recently parsed game state.
  GameState get lastState => _lastState;

  // Default patterns for Ancient Anguish.
  static final RegExp _basicPromptRegex = RegExp(r'(\d+)/(\d+):(\d+)/(\d+)>');

  static final RegExp _clientLineRegex = RegExp(
    r'CLIENT:X:(-?\d+):Y:(-?\d+):([\w]+):([\w]+):(\d+):(\d+)',
  );

  /// Custom prompt pattern set by user (null = use AA defaults).
  RegExp? _customPromptRegex;

  /// Sets a custom prompt regex pattern. Pass null to revert to defaults.
  void setCustomPattern(String? pattern) {
    if (pattern == null || pattern.isEmpty) {
      _customPromptRegex = null;
    } else {
      try {
        _customPromptRegex = RegExp(pattern);
      } catch (e) {
        debugPrint('PromptParser.setCustomPattern error: $e');
        _customPromptRegex = null;
      }
    }
  }

  /// Attempts to parse a line of MUD output for prompt data.
  ///
  /// Returns an updated [GameState] if the line contains prompt data,
  /// or `null` if the line is not a prompt.
  GameState? parseLine(String line) {
    // Try CLIENT line first (richest data).
    final clientState = _parseClientLine(line);
    if (clientState != null) {
      _lastState = clientState;
      return clientState;
    }

    // Try basic prompt.
    final basicState = _parseBasicPrompt(line);
    if (basicState != null) {
      _lastState = basicState;
      return basicState;
    }

    // Try custom pattern if set.
    if (_customPromptRegex != null) {
      final customState = _parseCustomPrompt(line);
      if (customState != null) {
        _lastState = customState;
        return customState;
      }
    }

    return null;
  }

  /// Resets the parser state (e.g., on disconnect).
  void reset() {
    _lastState = GameState.initial;
  }

  // ── Private parsers ──

  GameState? _parseBasicPrompt(String line) {
    final match = _basicPromptRegex.firstMatch(line);
    if (match == null) return null;

    return _lastState.copyWith(
      hp: int.parse(match.group(1)!),
      maxHp: int.parse(match.group(2)!),
      sp: int.parse(match.group(3)!),
      maxSp: int.parse(match.group(4)!),
    );
  }

  GameState? _parseClientLine(String line) {
    final match = _clientLineRegex.firstMatch(line);
    if (match == null) return null;

    return _lastState.copyWith(
      x: int.parse(match.group(1)!),
      y: int.parse(match.group(2)!),
      playerName: match.group(3),
      playerClass: match.group(4),
      coins: int.parse(match.group(5)!),
      xp: int.parse(match.group(6)!),
    );
  }

  GameState? _parseCustomPrompt(String line) {
    final match = _customPromptRegex!.firstMatch(line);
    if (match == null) return null;

    // Custom patterns are expected to have at least 4 groups: HP, MaxHP, SP, MaxSP.
    if (match.groupCount < 4) return null;

    try {
      return _lastState.copyWith(
        hp: int.parse(match.group(1)!),
        maxHp: int.parse(match.group(2)!),
        sp: int.parse(match.group(3)!),
        maxSp: int.parse(match.group(4)!),
      );
    } catch (e) {
      debugPrint('PromptParser._parseCustomPrompt error: $e');
      return null;
    }
  }
}
