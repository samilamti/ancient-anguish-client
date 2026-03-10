import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/widgets.dart' show FocusNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_info.dart';
import '../protocol/ansi/styled_span.dart';
import '../protocol/telnet/telnet_events.dart';
import '../services/connection/connection_service.dart';
import '../services/parser/output_parser.dart';
import 'game_state_provider.dart';
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
  static final RegExp _coordLineRegex = RegExp(r'^(-?\d+),(-?\d+)$');

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
          final processedLines = <StyledLine>[];

          for (final line in newLines) {
            // Login detection: send coord prompt after successful login.
            if (!_loginDetected &&
                line.plainText.contains('A player usage graph.')) {
              _loginDetected = true;
              service.sendCommand('prompt preset coords');
            }

            // Coordinate line detection: gag and capture.
            // Only active after login (when we've sent 'prompt preset coords').
            if (_loginDetected) {
              final coords = _parseCoordLine(line);
              if (coords != null) {
                gameNotifier.updateCoordinates(coords.$1, coords.$2);
                continue; // Gag – don't display or feed to prompt parser.
              }
            }

            // Normal trigger processing.
            final result = triggerEngine.processLine(line);
            if (!result.gagged) {
              processedLines.add(result.styledLine);
            }

            // Feed to game state parser for HP/SP prompt detection.
            gameNotifier.processLine(line.plainText);
          }

          if (processedLines.isNotEmpty) {
            _addLines(processedLines);
          }
        }
      } else if (event is TelnetCommandEvent) {
        // GA or EOR signals "end of prompt" – flush partial line.
        final flushed = parser.flush();
        if (flushed != null) {
          _addLines([flushed]);
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

  /// Checks if a styled line is a coordinate output from `prompt preset coords`.
  ///
  /// Returns the (x, y) pair if the entire trimmed line matches `N,N`, or null.
  /// Only called after login detection, so false positives are not a concern.
  (int, int)? _parseCoordLine(StyledLine line) {
    final trimmed = line.plainText.trim();
    final match = _coordLineRegex.firstMatch(trimmed);
    if (match == null) return null;
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// Clears the terminal buffer.
  void clear() => state = [];
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
