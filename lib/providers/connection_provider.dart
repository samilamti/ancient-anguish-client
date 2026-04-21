import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart' show FocusNode, TextEditingController;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/web_config.dart';
import '../models/prompt_element.dart';
import '../models/auth_state.dart';
import '../models/connection_info.dart';
import '../models/social_panel_state.dart';
import '../protocol/ansi/styled_span.dart';
import '../protocol/telnet/telnet_events.dart';
import '../services/connection/connection_interface.dart';
import '../services/connection/create_connection.dart';
import '../models/map_block.dart';
import '../services/parser/emoji_parser.dart';
import '../services/parser/link_parser.dart';
import '../services/parser/map_emoji_transformer.dart';
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
import 'map_block_provider.dart';
import 'online_players_provider.dart';
import 'prompt_config_provider.dart';
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

/// Shared [TextEditingController] for the command input bar.
///
/// Exposed so mobile quick-command buttons can pre-fill the input
/// (e.g. "kill " when no tab-completion targets exist yet).
final inputControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(() => controller.dispose());
  return controller;
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
  static final RegExp _ansiEscapeRegex = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]');

  /// How long to wait after the last incoming byte before flushing any
  /// buffered partial line as a synthetic prompt. The AA server sends
  /// prompts without `\n`, `IAC GA`, or `IAC EOR`, so the client must
  /// decide for itself when a line is "done". 150 ms is long enough to
  /// ride out packet fragmentation on bad networks while still feeling
  /// instant during character creation.
  static const Duration _promptFlushTimeout = Duration(milliseconds: 150);

  StreamSubscription<TelnetEvent>? _eventSub;
  StreamSubscription<ConnectionStatus>? _statusSub;
  Timer? _promptFlushTimer;
  bool _loginDetected = false;
  SocialMessageType? _lastSocialType;
  bool _inTellHistory = false;

  /// When true, emoji parsing is suppressed to preserve ASCII-art maps.
  ///
  /// Set by [suppressEmojiUntilPrompt] (user sent `read map`) or by
  /// detecting the map border `+---...---+`. Cleared when the next prompt
  /// arrives or the closing border is seen.
  bool _emojiSuppressed = false;

  /// Tracks whether we've already seen the opening map border and are
  /// waiting for the closing one.
  bool _insideMapBorder = false;

  /// Accumulator used when capturing a map block for grid rendering. Active
  /// only while `settings.emojiMapsEnabled` is on and we are between the
  /// opening and closing `+---+` borders.
  List<List<MapTile>>? _pendingMapRows;

  static final RegExp _mapBorderRegex =
      RegExp(r'^\+\-{20,}\+$');

  /// Called when the user sends a command that should suppress emoji
  /// parsing until the next prompt (e.g. `read map`).
  void suppressEmojiUntilPrompt() {
    _emojiSuppressed = true;
  }

  @override
  List<StyledLine> build() {
    _startListening();
    ref.onDispose(() {
      _eventSub?.cancel();
      _statusSub?.cancel();
      _promptFlushTimer?.cancel();
    });
    return [];
  }

  void _startListening() {
    // Cancel any existing subscriptions to prevent accumulation on rebuild.
    _eventSub?.cancel();
    _statusSub?.cancel();

    final service = ref.read(connectionServiceProvider);
    final parser = ref.read(outputParserProvider);

    // Resend prompt command when user changes Advanced Customization settings.
    ref.listen(promptConfigProvider, (previous, next) {
      if (_loginDetected && previous?.promptCommand != next.promptCommand) {
        service.sendCommand(next.promptCommand);
      }
    });

    _eventSub = service.events.listen((event) {
      if (event is TelnetDataEvent) {
        // New bytes arrived — any pending prompt-flush timer is now stale.
        _promptFlushTimer?.cancel();
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
              service.sendCommand(ref.read(promptConfigProvider).promptCommand);
            }

            // Prompt line detection: gag and capture HP/SP/coordinates.
            // The @@ markers make prompt text unmistakable. If the prompt
            // was pending and got prepended to this line, strip it out.
            if (_loginDetected) {
              final vitals = _extractPrompt(plainText);
              if (vitals != null) {
                promptDetected = true;
                // A prompt signals end-of-output — lift emoji suppression
                // that was triggered by `read map`.
                _emojiSuppressed = false;
                _insideMapBorder = false;
                gameNotifier.updateFromPrompt(vitals.values);
                // If the entire line was the prompt, gag it.
                if (vitals.remainder.isEmpty) continue;
                // Otherwise, re-parse the remainder as a new line.
                var remainderLine =
                    StyledLine([StyledSpan(text: vitals.remainder)]);
                final settings = ref.read(settingsProvider);
                if (settings.emojiParsingEnabled && !_emojiSuppressed) {
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

            // Map border detection: suppress emoji inside ASCII-art maps
            // delimited by +---...---+ borders. When emojiMapsEnabled, we
            // additionally capture the whole block into a structured
            // MapBlock and emit a single sentinel line in its place; the
            // terminal renderer expands that sentinel into a grid widget.
            final settings = ref.read(settingsProvider);
            final isBorder = _mapBorderRegex.hasMatch(plainText.trim());
            var captureLineIntoMap = false;
            var emitMapSentinel = false;
            int? finishedMapId;

            if (isBorder) {
              if (!_insideMapBorder) {
                // Opening border.
                _insideMapBorder = true;
                _emojiSuppressed = true;
                if (settings.emojiMapsEnabled) {
                  _pendingMapRows = <List<MapTile>>[];
                  continue; // Suppress the opening border line entirely.
                }
              } else {
                // Closing border.
                _insideMapBorder = false;
                if (settings.emojiMapsEnabled && _pendingMapRows != null) {
                  final rows = _pendingMapRows!;
                  _pendingMapRows = null;
                  if (rows.isNotEmpty) {
                    finishedMapId = ref
                        .read(mapBlocksProvider.notifier)
                        .put(MapBlock(rows));
                    emitMapSentinel = true;
                  }
                  _emojiSuppressed = false;
                  if (!emitMapSentinel) continue;
                }
              }
            } else if (_insideMapBorder &&
                settings.emojiMapsEnabled &&
                _pendingMapRows != null) {
              // Map content row — accumulate, don't add to buffer.
              final tiles = parseMapRow(plainText);
              if (tiles.isNotEmpty) _pendingMapRows!.add(tiles);
              captureLineIntoMap = true;
            }

            if (captureLineIntoMap) continue;

            // Build the line to emit. For a finished map, this is a
            // sentinel the renderer looks up; otherwise it's the usual
            // transformed/emoji-parsed line.
            var workingLine = line;
            if (emitMapSentinel && finishedMapId != null) {
              workingLine = StyledLine([
                StyledSpan(text: sentinelForBlockId(finishedMapId)),
              ]);
            } else if (settings.emojiMapsEnabled && _insideMapBorder) {
              // Rare path: user has maps enabled but accumulator missed a
              // line (e.g. flag flipped mid-block). Fall back to inline
              // emoji transform so the output remains legible.
              workingLine = MapEmojiTransformer.processLine(workingLine);
            }

            // Apply emoji parsing: replace text emoticons with emoji.
            final emojiLine =
                settings.emojiParsingEnabled && !_emojiSuppressed
                    ? EmojiParser.processLine(workingLine)
                    : workingLine;

            // Lift suppression after the closing border line is processed
            // (only reached when emojiMapsEnabled is off).
            if (!_insideMapBorder && _emojiSuppressed && isBorder) {
              _emojiSuppressed = false;
            }

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

            // Capture `qwho` output to populate the Tell-recipient list.
            ref.read(onlinePlayersProvider.notifier).processLine(plainText);
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
          if (ref.read(promptConfigProvider).promptRegex.hasMatch(pendingPlain)) {
            final flushed = parser.flush();
            if (flushed != null) {
              final vitals = _extractPrompt(flushed.plainText);
              if (vitals != null) {
                ref.read(gameStateProvider.notifier).updateFromPrompt(
                  vitals.values,
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

        // AA sends prompts with no terminator (no `\n`, no `IAC GA`, no
        // `IAC EOR`). If buffered data is still pending after this data
        // event — and doesn't look like a partial in-game `@@…@@` prompt
        // being delivered across packets — schedule a debounced flush so
        // the prompt text becomes visible without waiting for the next
        // line. Particularly important during character creation.
        if (parser.hasPendingData &&
            !_looksLikePartialPrompt(parser.pendingText)) {
          _promptFlushTimer = Timer(
            _promptFlushTimeout,
            _flushPendingAsPrompt,
          );
        }
      } else if (event is TelnetCommandEvent) {
        // GA or EOR signals "end of prompt" – flush partial line.
        _promptFlushTimer?.cancel();
        final flushed = parser.flush();
        if (flushed != null) {
          _emitFlushedPrompt(flushed);
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
        _promptFlushTimer?.cancel();
        _promptFlushTimer = null;
        ref.read(outputParserProvider).reset();
        ref.read(gameStateProvider.notifier).reset();
        ref.read(battleStateProvider.notifier).reset();
        ref.read(loginProvider.notifier).reset();
        _loginDetected = false;
        _lastSocialType = null;
        _inTellHistory = false;
        _emojiSuppressed = false;
        _insideMapBorder = false;
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

  /// Extracts prompt values from text containing `@@...@@` markers.
  ///
  /// Uses the dynamic regex and element list from [promptConfigProvider]
  /// so the parser adapts to the user's selected prompt elements.
  /// Returns the parsed values plus any text after the closing `@@` marker.
  _PromptMatch? _extractPrompt(String text) {
    final config = ref.read(promptConfigProvider);
    final match = config.promptRegex.firstMatch(text);
    if (match == null) return null;
    final remainder = text.substring(match.end).trim();
    final values = <PromptElementId, dynamic>{};
    for (var i = 0; i < config.activeElements.length; i++) {
      final element = config.activeElements[i];
      final raw = match.group(i + 1);
      if (raw == null) continue;
      values[element.id] = switch (element.dataType) {
        PromptDataType.integer => int.tryParse(raw) ?? 0,
        PromptDataType.signedInteger => int.tryParse(raw) ?? 0,
        PromptDataType.percentage => int.tryParse(raw) ?? 0,
        PromptDataType.string => raw,
      };
    }
    return _PromptMatch(values: values, remainder: remainder);
  }

  /// Marks login as complete (called by [LoginNotifier] after credentials are
  /// sent, so prompt line gagging activates).
  void setLoginDetected() => _loginDetected = true;

  /// True if [pending] looks like an in-flight `@@…@@` game prompt that
  /// hasn't finished arriving yet. Used to suppress the debounced flush
  /// so a prompt split across TCP packets doesn't leak the first half
  /// into the terminal as a plain line.
  bool _looksLikePartialPrompt(String pending) {
    final stripped = pending.replaceAll(_ansiEscapeRegex, '').trimLeft();
    return stripped.startsWith('@@') &&
        !ref.read(promptConfigProvider).promptRegex.hasMatch(stripped);
  }

  /// Timer callback: flush buffered partial text as a synthetic prompt
  /// line, unless the `@@…@@` regex has meanwhile started matching (in
  /// which case we still route through the prompt-gagging path).
  void _flushPendingAsPrompt() {
    _promptFlushTimer = null;
    final parser = ref.read(outputParserProvider);
    if (!parser.hasPendingData) return;

    if (_loginDetected) {
      final pendingPlain =
          parser.pendingText.replaceAll(_ansiEscapeRegex, '');
      if (ref.read(promptConfigProvider).promptRegex.hasMatch(pendingPlain)) {
        final flushed = parser.flush();
        if (flushed != null) {
          final vitals = _extractPrompt(flushed.plainText);
          if (vitals != null) {
            ref
                .read(gameStateProvider.notifier)
                .updateFromPrompt(vitals.values);
            if (ref.read(settingsProvider).blockModeEnabled) {
              ref
                  .read(blockBoundaryProvider.notifier)
                  .markPromptBoundary(state.length);
            }
          }
        }
        return;
      }
    }

    final flushed = parser.flush();
    if (flushed != null) {
      _emitFlushedPrompt(flushed);
    }
  }

  /// Shared flush-and-emit logic used by both the `IAC GA`/`IAC EOR`
  /// branch and the debounced prompt-flush timer.
  void _emitFlushedPrompt(StyledLine flushed) {
    final service = ref.read(connectionServiceProvider);
    final plainText = flushed.plainText;

    // Login dialog: detect "Password:" prompt.
    if (plainText.contains('Password:')) {
      ref.read(loginProvider.notifier).onPasswordPromptDetected();
    }

    // Fallback login detection for guest/manual login.
    if (!_loginDetected && plainText.contains('A player usage graph.')) {
      _loginDetected = true;
      service.sendCommand(ref.read(promptConfigProvider).promptCommand);
    }

    // Prompt line detection: gag and capture HP/SP/coordinates.
    if (_loginDetected) {
      final vitals = _extractPrompt(plainText);
      if (vitals != null) {
        ref.read(gameStateProvider.notifier).updateFromPrompt(vitals.values);
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

  /// Clears the terminal buffer (and any captured map blocks).
  void clear() {
    state = [];
    ref.read(mapBlocksProvider.notifier).clear();
  }
}

/// Parsed prompt values plus any trailing text that followed the prompt.
class _PromptMatch {
  final Map<PromptElementId, dynamic> values;
  final String remainder;
  const _PromptMatch({required this.values, required this.remainder});
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
