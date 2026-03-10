import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/widgets.dart' show FocusNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_info.dart';
import '../protocol/ansi/styled_span.dart';
import '../protocol/telnet/telnet_events.dart';
import '../services/connection/connection_service.dart';
import '../services/parser/output_parser.dart';
import 'battle_provider.dart';
import 'game_state_provider.dart';
import 'login_provider.dart';
import 'trigger_provider.dart';

/// Provides the singleton [ConnectionService].
final connectionServiceProvider = Provider<ConnectionService>((ref) {
  final service = ConnectionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provides the current [ConnectionStatus] as a stream.
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final service = ref.watch(connectionServiceProvider);
  return service.statusStream;
});

/// Provides the [OutputParser] for converting raw data to styled lines.
final outputParserProvider = Provider<OutputParser>((ref) {
  return OutputParser();
});

/// Shared [FocusNode] for the command input bar.
///
/// Used by the terminal view to focus the input when the user taps the output.
final inputFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode();
  ref.onDispose(() => node.dispose());
  return node;
});

/// The terminal buffer – a list of styled lines representing all output.
///
/// This is the core state that the terminal view renders.
final terminalBufferProvider =
    NotifierProvider<TerminalBufferNotifier, List<StyledLine>>(
        TerminalBufferNotifier.new);

/// Manages the terminal output buffer, listening to connection events and
/// parsing them into styled lines.
class TerminalBufferNotifier extends Notifier<List<StyledLine>> {
  static const int _maxLines = 10000;
  static const String _promptCommand =
      'prompt set @@|HP| |MAXHP| |SP| |MAXSP| |XCOORD| |YCOORD|@@';
  static final RegExp _promptLineRegex = RegExp(
      r'@@\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(-?\d+)\s+(-?\d+)@@');
  static final RegExp _ansiEscapeRegex = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');

  StreamSubscription<TelnetEvent>? _eventSub;
  StreamSubscription<ConnectionStatus>? _statusSub;
  bool _loginDetected = false;

  @override
  List<StyledLine> build() {
    _startListening();
    ref.onDispose(() {
      _eventSub?.cancel();
      _statusSub?.cancel();
    });
    return [];
  }

  void _startListening() {
    // Cancel any existing subscriptions to prevent accumulation on rebuild.
    _eventSub?.cancel();
    _statusSub?.cancel();

    final service = ref.read(connectionServiceProvider);
    final parser = ref.read(outputParserProvider);

    _eventSub = service.events.listen((event) {
      if (event is TelnetDataEvent) {
        final newLines = parser.processBytes(event.data);
        if (newLines.isNotEmpty) {
          final triggerEngine = ref.read(triggerEngineProvider);
          final gameNotifier = ref.read(gameStateProvider.notifier);
          final battleNotifier = ref.read(battleStateProvider.notifier);
          final processedLines = <StyledLine>[];

          for (final line in newLines) {
            final plainText = line.plainText;

            // Login dialog: detect "Password:" prompt.
            if (plainText.contains('Password:')) {
              ref.read(loginProvider.notifier).onPasswordPromptDetected();
            }

            // Fallback login detection for guest/manual login.
            if (!_loginDetected &&
                plainText.contains('A player usage graph.')) {
              _loginDetected = true;
              service.sendCommand(_promptCommand);
            }

            // Prompt line detection: gag and capture HP/SP/coordinates.
            // The @@ markers make prompt text unmistakable. If the prompt
            // was pending and got prepended to this line, strip it out.
            if (_loginDetected) {
              final vitals = _extractPrompt(plainText);
              if (vitals != null) {
                gameNotifier.updateVitalsAndCoordinates(
                  vitals.hp, vitals.maxHp, vitals.sp,
                  vitals.maxSp, vitals.x, vitals.y,
                );
                // If the entire line was the prompt, gag it.
                if (vitals.remainder.isEmpty) continue;
                // Otherwise, re-parse the remainder as a new line.
                final remainderLine =
                    StyledLine([StyledSpan(text: vitals.remainder)]);
                final result = triggerEngine.processLine(remainderLine);
                if (!result.gagged) {
                  processedLines.add(result.styledLine);
                }
                gameNotifier.processLine(vitals.remainder);
                continue;
              }
            }

            // Battle pattern detection: "HP: 136  SP: 149" and miss messages.
            final battleVitals = BattleNotifier.parseBattleLine(plainText);
            if (battleVitals != null) {
              gameNotifier.updateCurrentVitals(
                hp: battleVitals.hp,
                sp: battleVitals.sp,
              );
              battleNotifier.onBattlePatternDetected();
            } else if (BattleNotifier.isBattleIndicator(plainText)) {
              battleNotifier.onBattlePatternDetected();
            }

            // Normal trigger processing.
            final result = triggerEngine.processLine(line);
            if (!result.gagged) {
              processedLines.add(result.styledLine);
            }

            // Feed to game state parser for HP/SP prompt detection.
            gameNotifier.processLine(plainText);
          }

          if (processedLines.isNotEmpty) {
            _addLines(processedLines);
          }
        }

        // The MUD uses SGA (Suppress Go Ahead), so prompt lines arrive
        // without a trailing newline or GA. They stay in the parser's
        // buffer as pending data. Consume them here before the next data
        // event prepends them to the following output line.
        if (_loginDetected && parser.hasPendingData) {
          final pendingPlain = parser.pendingText
              .replaceAll(_ansiEscapeRegex, '');
          if (_promptLineRegex.hasMatch(pendingPlain)) {
            final flushed = parser.flush();
            if (flushed != null) {
              final vitals = _extractPrompt(flushed.plainText);
              if (vitals != null) {
                ref.read(gameStateProvider.notifier).updateVitalsAndCoordinates(
                  vitals.hp, vitals.maxHp, vitals.sp,
                  vitals.maxSp, vitals.x, vitals.y,
                );
              }
            }
          }
        }

        // Check pending text for password prompt.
        if (parser.hasPendingData &&
            parser.pendingText.contains('Password:')) {
          ref.read(loginProvider.notifier).onPasswordPromptDetected();
        }
      } else if (event is TelnetCommandEvent) {
        // GA or EOR signals "end of prompt" – flush partial line.
        final flushed = parser.flush();
        if (flushed != null) {
          final plainText = flushed.plainText;

          // Login dialog: detect "Password:" prompt.
          if (plainText.contains('Password:')) {
            ref.read(loginProvider.notifier).onPasswordPromptDetected();
          }

          // Fallback login detection for guest/manual login.
          if (!_loginDetected &&
              plainText.contains('A player usage graph.')) {
            _loginDetected = true;
            service.sendCommand(_promptCommand);
          }

          // Prompt line detection: gag and capture HP/SP/coordinates.
          if (_loginDetected) {
            final vitals = _extractPrompt(plainText);
            if (vitals != null) {
              ref.read(gameStateProvider.notifier).updateVitalsAndCoordinates(
                vitals.hp, vitals.maxHp, vitals.sp,
                vitals.maxSp, vitals.x, vitals.y,
              );
              return; // Gagged.
            }
          }

          // Normal trigger processing.
          final triggerEngine = ref.read(triggerEngineProvider);
          final result = triggerEngine.processLine(flushed);
          if (!result.gagged) {
            _addLines([result.styledLine]);
          }

          // Feed to game state parser.
          ref.read(gameStateProvider.notifier).processLine(plainText);
        }
      }
    }, onError: (error) {
      // Show connection errors in the terminal.
      _addLines([
        StyledLine([
          StyledSpan(
            text: '*** $error',
            foreground: const Color(0xFFFF5555),
            bold: true,
          ),
        ]),
      ]);
    });

    _statusSub = service.statusStream.listen((status) {
      // Show login dialog as soon as we connect.
      if (status == ConnectionStatus.connected) {
        ref.read(loginProvider.notifier).onNamePromptDetected();
      }

      final message = switch (status) {
        ConnectionStatus.connecting =>
          '*** Connecting to ${service.connectionInfo}...',
        ConnectionStatus.connected => '*** Connected!',
        ConnectionStatus.disconnected => '*** Disconnected.',
        ConnectionStatus.disconnecting => '*** Disconnecting...',
        ConnectionStatus.error => '*** Connection error.',
      };
      _addLines([
        StyledLine([
          StyledSpan(
            text: message,
            foreground: const Color(0xFFAAAA00),
            bold: true,
          ),
        ]),
      ]);

      // Reset parsers and login detection on disconnect.
      if (status == ConnectionStatus.disconnected) {
        ref.read(outputParserProvider).reset();
        ref.read(gameStateProvider.notifier).reset();
        ref.read(battleStateProvider.notifier).reset();
        ref.read(loginProvider.notifier).reset();
        _loginDetected = false;
      }
    });
  }

  void _addLines(List<StyledLine> lines) {
    final newState = [...state, ...lines];
    // Trim to max lines.
    if (newState.length > _maxLines) {
      state = newState.sublist(newState.length - _maxLines);
    } else {
      state = newState;
    }
  }

  /// Extracts vitals from text containing `@@HP MAXHP SP MAXSP X Y@@`.
  ///
  /// Returns the parsed values plus any text after the closing `@@` marker
  /// (in case the prompt was prepended to the next output line).
  static _PromptMatch? _extractPrompt(String text) {
    final match = _promptLineRegex.firstMatch(text);
    if (match == null) return null;
    final remainder = text.substring(match.end).trim();
    return _PromptMatch(
      hp: int.parse(match.group(1)!),
      maxHp: int.parse(match.group(2)!),
      sp: int.parse(match.group(3)!),
      maxSp: int.parse(match.group(4)!),
      x: int.parse(match.group(5)!),
      y: int.parse(match.group(6)!),
      remainder: remainder,
    );
  }

  /// Marks login as complete (called by [LoginNotifier] after credentials are
  /// sent, so prompt line gagging activates).
  void setLoginDetected() => _loginDetected = true;

  /// Clears the terminal buffer.
  void clear() => state = [];
}

/// Parsed prompt values plus any trailing text that followed the prompt.
class _PromptMatch {
  final int hp, maxHp, sp, maxSp, x, y;
  final String remainder;
  const _PromptMatch({
    required this.hp,
    required this.maxHp,
    required this.sp,
    required this.maxSp,
    required this.x,
    required this.y,
    required this.remainder,
  });
}

/// Provides command history.
final commandHistoryProvider =
    NotifierProvider<CommandHistoryNotifier, List<String>>(
        CommandHistoryNotifier.new);

/// Manages the user's command history for up/down arrow recall.
class CommandHistoryNotifier extends Notifier<List<String>> {
  static const int _maxHistory = 500;
  int _position = -1;

  @override
  List<String> build() => [];

  /// Adds a command to history (most recent first).
  void add(String command) {
    if (command.trim().isEmpty) return;
    // Remove duplicate if it's the same as the most recent.
    if (state.isNotEmpty && state.first == command) {
      _position = -1;
      return;
    }
    final newState = [command, ...state];
    if (newState.length > _maxHistory) {
      state = newState.sublist(0, _maxHistory);
    } else {
      state = newState;
    }
    _position = -1;
  }

  /// Navigates backward (older) in history. Returns the command or null.
  String? previous() {
    if (state.isEmpty) return null;
    if (_position < state.length - 1) {
      _position++;
    }
    return state[_position];
  }

  /// Navigates forward (newer) in history. Returns the command or null.
  String? next() {
    if (_position <= 0) {
      _position = -1;
      return '';
    }
    _position--;
    return state[_position];
  }

  /// Resets the navigation position.
  void resetPosition() => _position = -1;
}
