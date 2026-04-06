import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart' show FocusNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/web_config.dart';
import '../models/auth_state.dart';
import '../models/connection_info.dart';
import '../models/social_panel_state.dart';
import '../protocol/ansi/styled_span.dart';
import '../protocol/telnet/telnet_events.dart';
import '../services/connection/connection_interface.dart';
import '../services/connection/create_connection.dart';
import '../services/parser/emoji_parser.dart';
import '../services/parser/link_parser.dart';
import '../services/parser/output_parser.dart';
import '../models/social_message.dart';
import '../services/command_history_service.dart';
import '../services/platform/window_service.dart';
import 'auth_provider.dart';
import 'storage_provider.dart';
import '../services/social/social_message_parser.dart';
import 'battle_provider.dart';
import 'game_state_provider.dart';
import 'login_provider.dart';
import 'settings_provider.dart';
import 'social_message_provider.dart';
import 'social_panel_provider.dart';
import 'recent_words_provider.dart';
import 'terminal_block_provider.dart';
import 'trigger_provider.dart';

/// Provides the singleton [MudConnectionService].
///
/// Desktop: [TcpConnectionService] (raw TCP socket).
/// Web: [WebConnectionService] (WebSocket via server proxy).
///
/// Platform selection is handled at compile time via conditional imports
/// in `create_connection.dart`.
final connectionServiceProvider = Provider<MudConnectionService>((ref) {
  MudConnectionService service;
  if (kIsWeb) {
    final authState = ref.watch(authProvider);
    if (authState is! AuthAuthenticated) {
      throw StateError('ConnectionService requires authentication on web');
    }
    service = createConnectionService(
      serverUrl: WebConfig.serverUrl,
      tokenProvider: () => ref.read(authProvider.notifier).token ?? '',
    );
  } else {
    service = createConnectionService();
  }
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
  static const int _maxLines = 5000;
  static const String _promptCommand =
      'prompt set @@|HP| |MAXHP| |SP| |MAXSP| |XCOORD| |YCOORD|@@';
  static final RegExp _promptLineRegex = RegExp(
      r'@@\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(-?\d+)\s+(-?\d+)@@');
  static final RegExp _ansiEscapeRegex = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');

  StreamSubscription<TelnetEvent>? _eventSub;
  StreamSubscription<ConnectionStatus>? _statusSub;
  bool _loginDetected = false;
  SocialMessageType? _lastSocialType;
  bool _inTellHistory = false;

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
          var promptDetected = false;

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
                promptDetected = true;
                gameNotifier.updateVitalsAndCoordinates(
                  vitals.hp, vitals.maxHp, vitals.sp,
                  vitals.maxSp, vitals.x, vitals.y,
                );
                // If the entire line was the prompt, gag it.
                if (vitals.remainder.isEmpty) continue;
                // Otherwise, re-parse the remainder as a new line.
                var remainderLine =
                    StyledLine([StyledSpan(text: vitals.remainder)]);
                final settings = ref.read(settingsProvider);
                if (settings.emojiParsingEnabled) {
                  remainderLine = EmojiParser.processLine(remainderLine);
                }
                final result = triggerEngine.processLine(remainderLine);
                if (!result.gagged) {
                  processedLines.add(result.styledLine);
                }
                gameNotifier.processLine(vitals.remainder);
                gameNotifier.processRoomText(vitals.remainder);
                continue;
              }
            }

            // Apply emoji parsing: replace text emoticons with emoji.
            final settings = ref.read(settingsProvider);
            final emojiLine = settings.emojiParsingEnabled
                ? EmojiParser.processLine(line)
                : line;

            // Tell history block: "thistory" / "tell $" output should not
            // be captured into the social tells window.
            if (plainText.contains('-- Summary tell history start --')) {
              _inTellHistory = true;
            } else if (plainText.contains('--  Summary tell history end  --')) {
              _inTellHistory = false;
            }

            // Social message interception: route [Chat] and tell lines
            // to their dedicated buffers. When gagging is enabled, skip
            // adding them to the main terminal.
            if (_loginDetected && !_inTellHistory) {
              final socialResult =
                  _processSocialLine(emojiLine, plainText);
              if (socialResult != _SocialLineResult.notSocial) {
                if (settings.socialWindowsEnabled &&
                    isDesktopPlatform() &&
                    settings.gagSocialFromTerminal &&
                    _isSocialPanelVisible()) {
                  continue;
                }
              }
            }

            // Headache event: suppress battle detection for the HP dip.
            if (plainText.contains(
                'You suddenly without reason get a bad headache.')) {
              battleNotifier.suppressDetection(const Duration(seconds: 5));
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

            // Extract capitalized words for TAB completion.
            ref.read(recentWordsProvider.notifier).extractFromLine(plainText);

            // Normal trigger processing.
            final result = triggerEngine.processLine(emojiLine);
            if (!result.gagged) {
              processedLines.add(result.styledLine);
            }

            // Feed to game state parser for HP/SP prompt detection.
            gameNotifier.processLine(plainText);
            gameNotifier.processRoomText(plainText);
          }

          if (processedLines.isNotEmpty) {
            _addLines(processedLines);
          }

          // Emit a prompt boundary for block mode when a prompt was detected.
          if (promptDetected &&
              ref.read(settingsProvider).blockModeEnabled) {
            ref
                .read(blockBoundaryProvider.notifier)
                .markPromptBoundary(state.length);
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
                // Prompt boundary for block mode.
                if (ref.read(settingsProvider).blockModeEnabled) {
                  ref
                      .read(blockBoundaryProvider.notifier)
                      .markPromptBoundary(state.length);
                }
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

          // Apply emoji parsing and trigger processing.
          final settings = ref.read(settingsProvider);
          final emojiLine = settings.emojiParsingEnabled
              ? EmojiParser.processLine(flushed)
              : flushed;
          final triggerEngine = ref.read(triggerEngineProvider);
          final result = triggerEngine.processLine(emojiLine);
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
        _lastSocialType = null;
        _inTellHistory = false;
        ref.read(blockBoundaryProvider.notifier).reset();
      }
    });
  }

  _SocialLineResult _processSocialLine(StyledLine line, String plainText) {
    final chatNotifier = ref.read(chatMessagesProvider.notifier);
    final tellNotifier = ref.read(tellMessagesProvider.notifier);
    final partyNotifier = ref.read(partyMessagesProvider.notifier);

    // Check for party line: "<Party Name> Character : message" or emote
    final partyMatch = SocialMessageParser.matchPartyLine(plainText);
    if (partyMatch != null &&
        !SocialMessageParser.isPartySystemMessage(partyMatch)) {
      _lastSocialType = SocialMessageType.party;
      // Say: "Character: message", Emote: "Character does something"
      final displayBody = partyMatch.isEmote
          ? '${partyMatch.sender} ${partyMatch.text}'
          : '${partyMatch.sender}: ${partyMatch.text}';
      final displayLine = StyledLine([StyledSpan(text: displayBody)]).collapseSpaces();
      partyNotifier.addMessage(SocialMessage(
        type: SocialMessageType.party,
        sender: partyMatch.sender,
        body: displayBody,
        styledLines: [displayLine],
        timestamp: DateTime.now(),
      ));
      _markUnreadIfInactive(tabIndex: 2);
      _autoActivateTab(2);
      return _SocialLineResult.captured;
    }

    // Check for chat line.
    final chatMatch = SocialMessageParser.matchChatLine(plainText);
    if (chatMatch != null &&
        !SocialMessageParser.isChatSystemMessage(chatMatch)) {
      _lastSocialType = SocialMessageType.chat;
      // Strip "[Chat] " prefix for cleaner display in the social window.
      final prefixLen = plainText.indexOf(chatMatch.sender);
      final displayLine = LinkParser.processLine(line).subLine(prefixLen).collapseSpaces();
      final displayBody = plainText.substring(prefixLen).replaceAll(RegExp(r' {2,}'), ' ');
      chatNotifier.addMessage(SocialMessage(
        type: SocialMessageType.chat,
        sender: chatMatch.sender,
        body: displayBody,
        styledLines: [displayLine],
        timestamp: DateTime.now(),
      ));
      _markUnreadIfInactive(tabIndex: 0);
      _autoActivateTab(0);
      return _SocialLineResult.captured;
    }

    // Check for tell line (skip NPC tells — keep them in main terminal).
    final tellMatch = SocialMessageParser.matchTellLine(plainText);
    if (tellMatch != null &&
        !(!tellMatch.isOutgoing && SocialMessageParser.isTellNpc(tellMatch))) {
      _lastSocialType = tellMatch.isOutgoing
          ? SocialMessageType.tellOutgoing
          : SocialMessageType.tellIncoming;
      final processedLine = LinkParser.processLine(line);
      StyledLine displayLine;
      String displayBody;
      if (tellMatch.isOutgoing) {
        // "You tell Foo: hello" → "➡️ Foo: hello"
        displayLine = processedLine.subLine(9).collapseSpaces().prepend('\u27A1\uFE0F ');
        displayBody = '\u27A1\uFE0F ${plainText.substring(9).replaceAll(RegExp(r' {2,}'), ' ')}';
      } else {
        // "Foo tells you: hello" → "Foo: hello"
        final removeStart = tellMatch.sender.length;
        displayLine = processedLine.removeRange(
            removeStart, removeStart + ' tells you'.length).collapseSpaces();
        displayBody = plainText.replaceFirst(' tells you:', ':').replaceAll(RegExp(r' {2,}'), ' ');
      }
      tellNotifier.addMessage(SocialMessage(
        type: _lastSocialType!,
        sender: tellMatch.sender,
        body: displayBody,
        styledLines: [displayLine],
        timestamp: DateTime.now(),
      ));
      if (!tellMatch.isOutgoing) {
        tellNotifier.setLastRecipient(tellMatch.sender);
        _markUnreadIfInactive(tabIndex: 1);
        _autoActivateTab(1);
        WindowService.requestAttention();
      }
      return _SocialLineResult.captured;
    }

    // Check for continuation of a previous social message.
    if (_lastSocialType != null &&
        SocialMessageParser.isContinuation(plainText)) {
      if (_lastSocialType == SocialMessageType.chat) {
        chatNotifier.appendContinuation(line, plainText);
      } else if (_lastSocialType == SocialMessageType.party) {
        partyNotifier.appendContinuation(line, plainText);
      } else {
        tellNotifier.appendContinuation(line, plainText);
      }
      return _SocialLineResult.continuation;
    }

    // Not a social line — reset continuation tracking.
    _lastSocialType = null;
    return _SocialLineResult.notSocial;
  }

  /// Whether the social panel for the current message type is visible.
  /// When panels are hidden, messages should pass through to the terminal.
  bool _isSocialPanelVisible() {
    final ps = ref.read(socialPanelProvider);
    if (ps.tabMode == PanelTabMode.tabbed) {
      return ps.chatPanel.visible && ps.tellsPanel.visible && ps.partyPanel.visible;
    }
    // Separate mode — check the specific panel.
    if (_lastSocialType == SocialMessageType.chat) {
      return ps.chatPanel.visible;
    }
    if (_lastSocialType == SocialMessageType.party) {
      return ps.partyPanel.visible;
    }
    return ps.tellsPanel.visible;
  }

  /// Auto-switches the social tab when the terminal input bar has focus.
  /// Only applies in tabbed mode — separate panels are already visible.
  /// Throttled to at most once every 2 seconds to avoid rapid tab flipping.
  DateTime? _lastAutoSwitchTime;

  void _autoActivateTab(int tabIndex) {
    final panelState = ref.read(socialPanelProvider);
    if (panelState.tabMode != PanelTabMode.tabbed) return;
    if (panelState.activeTab == tabIndex) return;
    if (!ref.read(inputFocusProvider).hasFocus) return;

    final now = DateTime.now();
    if (_lastAutoSwitchTime != null &&
        now.difference(_lastAutoSwitchTime!).inMilliseconds < 2000) {
      return;
    }

    _lastAutoSwitchTime = now;
    ref.read(socialPanelProvider.notifier).setActiveTab(tabIndex);
  }

  /// Marks a social tab as having unread messages if not active.
  /// tabIndex: 0=chat, 1=tells, 2=party.
  void _markUnreadIfInactive({required int tabIndex}) {
    final panelState = ref.read(socialPanelProvider);
    final panelNotifier = ref.read(socialPanelProvider.notifier);

    if (panelState.tabMode == PanelTabMode.tabbed) {
      if (panelState.activeTab != tabIndex) {
        if (tabIndex == 0) panelNotifier.markChatUnread();
        if (tabIndex == 1) panelNotifier.markTellsUnread();
        if (tabIndex == 2) panelNotifier.markPartyUnread();
      }
    } else {
      // In separate mode, mark unread if the panel isn't visible.
      if (tabIndex == 0 && !panelState.chatPanel.visible) {
        panelNotifier.markChatUnread();
      } else if (tabIndex == 1 && !panelState.tellsPanel.visible) {
        panelNotifier.markTellsUnread();
      } else if (tabIndex == 2 && !panelState.partyPanel.visible) {
        panelNotifier.markPartyUnread();
      }
    }
  }

  void _addLines(List<StyledLine> lines) {
    final newState = [...state, ...lines.map(LinkParser.processLine)];
    // Trim to max lines.
    if (newState.length > _maxLines) {
      final removedCount = newState.length - _maxLines;
      state = newState.sublist(removedCount);
      // Adjust block boundaries to account for trimmed lines.
      if (ref.read(settingsProvider).blockModeEnabled) {
        ref.read(blockBoundaryProvider.notifier).adjustForTrim(removedCount);
      }
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

/// Result of checking a line for social message content.
enum _SocialLineResult { captured, continuation, notSocial }

/// Provides command history.
final commandHistoryProvider =
    NotifierProvider<CommandHistoryNotifier, List<String>>(
        CommandHistoryNotifier.new);

/// Manages the user's command history for up/down arrow recall.
///
/// Supports prefix-filtered navigation: when the user has typed a partial
/// command, Up/Down only cycle through history entries that start with that
/// prefix. An empty prefix matches everything (original behavior).
class CommandHistoryNotifier extends Notifier<List<String>> {
  static const int _maxHistory = CommandHistoryService.maxEntries;
  int _position = -1;

  /// The prefix used to filter history during the current navigation session.
  /// Set on the first Up press and cleared when navigation resets.
  String? _filterPrefix;

  /// Indices into [state] that match [_filterPrefix].
  List<int> _filteredIndices = [];

  /// Current position within [_filteredIndices].
  int _filteredPosition = -1;

  @override
  List<String> build() {
    _loadFromDisk();
    return [];
  }

  Future<void> _loadFromDisk() async {
    try {
      final storage = ref.read(storageServiceProvider);
      final commands = await CommandHistoryService.loadHistory(storage);
      if (commands.isNotEmpty) {
        state = commands;
      }
    } catch (e) {
      debugPrint('CommandHistoryNotifier._loadFromDisk: $e');
    }
  }

  /// Adds a command to history (most recent first).
  void add(String command) {
    if (command.trim().isEmpty) return;
    // Remove duplicate if it's the same as the most recent.
    if (state.isNotEmpty && state.first == command) {
      _position = -1;
      _resetFilter();
      return;
    }
    final newState = [command, ...state];
    if (newState.length > _maxHistory) {
      state = newState.sublist(0, _maxHistory);
    } else {
      state = newState;
    }
    _position = -1;
    _resetFilter();
    CommandHistoryService.appendCommand(ref.read(storageServiceProvider), command);
  }

  /// Navigates backward (older) in history, filtered by [prefix].
  ///
  /// On the first call of a navigation session, builds a filtered index list
  /// of history entries starting with [prefix]. Subsequent calls cycle through
  /// that list. An empty prefix matches all entries.
  String? previous(String prefix) {
    if (state.isEmpty) return null;

    // Start a new filtered session if prefix changed or no session active.
    if (_filterPrefix == null || _filterPrefix != prefix) {
      _filterPrefix = prefix;
      _buildFilteredIndices(prefix);
      _filteredPosition = -1;
    }

    if (_filteredIndices.isEmpty) return null;

    if (_filteredPosition < _filteredIndices.length - 1) {
      _filteredPosition++;
    }
    _position = _filteredIndices[_filteredPosition];
    return state[_position];
  }

  /// Navigates forward (newer) in history within the current filter.
  String? next() {
    if (_filterPrefix == null || _filteredIndices.isEmpty) {
      _position = -1;
      return '';
    }

    if (_filteredPosition <= 0) {
      _position = -1;
      _filteredPosition = -1;
      return _filterPrefix ?? '';
    }
    _filteredPosition--;
    _position = _filteredIndices[_filteredPosition];
    return state[_position];
  }

  /// Resets the navigation position and filter.
  void resetPosition() {
    _position = -1;
    _resetFilter();
  }

  void _resetFilter() {
    _filterPrefix = null;
    _filteredIndices = [];
    _filteredPosition = -1;
  }

  void _buildFilteredIndices(String prefix) {
    if (prefix.isEmpty) {
      _filteredIndices = List.generate(state.length, (i) => i);
    } else {
      _filteredIndices = [
        for (int i = 0; i < state.length; i++)
          if (state[i].startsWith(prefix)) i,
      ];
    }
  }
}
