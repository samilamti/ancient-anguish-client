import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/alias_provider.dart';
import '../../../providers/connection_provider.dart'
    show connectionServiceProvider, commandHistoryProvider, inputFocusProvider,
    inputControllerProvider, terminalBufferProvider;
import '../../../providers/game_state_provider.dart';
import '../../../providers/login_provider.dart'
    show loginProvider, LoginPromptDetected;
import '../../../providers/recent_words_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/social_panel_provider.dart';
import '../../../models/social_panel_state.dart';
import '../../../services/command_counterparts.dart';
import '../../../services/parser/emoji_parser.dart';

/// The command input bar at the bottom of the terminal.
///
/// Supports:
/// - Sending commands with Enter key or send button.
/// - Command history navigation with Up/Down arrow keys.
/// - Command repeat with Up+Enter.
class InputBar extends ConsumerStatefulWidget {
  const InputBar({super.key});

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<InputBar> {
  late final TextEditingController _controller =
      ref.read(inputControllerProvider);
  late final FocusNode _focusNode = ref.read(inputFocusProvider);

  // TAB completion state.
  String? _tabPrefix;
  int _tabInsertStart = 0;
  int _tabCycleIndex = -1;
  List<String> _tabMatches = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    // Both _controller and _focusNode are owned by Riverpod providers and
    // disposed via ref.onDispose — don't dispose them here.
    super.dispose();
  }

  /// Select all text when the input bar gains focus.
  void _onFocusChange() {
    if (_focusNode.hasFocus && _controller.text.isNotEmpty) {
      Future.microtask(() {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
    }
  }

  void _send() {
    final command = _controller.text;
    final service = ref.read(connectionServiceProvider);
    final history = ref.read(commandHistoryProvider.notifier);
    final aliasEngine = ref.read(aliasEngineProvider);

    // Expand aliases — may produce multiple commands (semicolons).
    final expanded = aliasEngine.expand(command);
    final settings = ref.read(settingsProvider);
    for (final cmd in expanded) {
      // Suppress emoji parsing for map output so ASCII art renders cleanly.
      if (cmd.trim().toLowerCase() == 'read map') {
        ref.read(terminalBufferProvider.notifier).suppressEmojiUntilPrompt();
      }
      final outgoing = settings.emojiParsingEnabled
          ? EmojiParser.reverseEmojis(cmd)
          : cmd;
      service.sendCommand(outgoing);
    }
    history.add(command);
    _resetHistorySearch();
    ref.read(gameStateProvider.notifier).recordDirectionalAttempt(command);
    // Select all text so the user can resend with Enter or type to replace.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );

    // On mobile with keyboard-hiding enabled, dismiss the keyboard after
    // sending so the user can see more of the output. Otherwise keep focus.
    if (_shouldHideKeyboard(settings)) {
      _focusNode.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } else {
      _focusNode.requestFocus();
    }
  }

  /// Whether mobile keyboard-hiding is active for the current layout.
  bool _shouldHideKeyboard(AppSettings settings) {
    if (!settings.hideKeyboardOnMobile) return false;
    final width = MediaQuery.of(context).size.width;
    return width < 768;
  }

  /// The text in the input bar when the user first pressed Up.
  /// Used as the prefix filter for history navigation.
  String? _historySearchPrefix;

  void _historyUp() {
    final history = ref.read(commandHistoryProvider.notifier);
    // On the first Up press, capture the current input as the search prefix.
    _historySearchPrefix ??= _controller.text;
    final previous = history.previous(_historySearchPrefix!);
    if (previous != null) {
      _controller.text = previous;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  void _historyDown() {
    final history = ref.read(commandHistoryProvider.notifier);
    final next = history.next();
    if (next != null) {
      _controller.text = next;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  void _resetHistorySearch() {
    _historySearchPrefix = null;
    ref.read(commandHistoryProvider.notifier).resetPosition();
  }

  void _resetTabCompletion() {
    _tabPrefix = null;
    _tabCycleIndex = -1;
    _tabMatches = [];
  }

  void _handleTab() {
    final words = ref.read(recentWordsProvider);
    if (words.isEmpty) return;

    if (_tabPrefix == null) {
      // Start a new completion cycle.
      final text = _controller.text;
      final cursor = _controller.selection.baseOffset;
      if (cursor < 0) return;

      // Scan backwards from cursor to find word start.
      var wordStart = cursor;
      while (wordStart > 0 && text[wordStart - 1] != ' ') {
        wordStart--;
      }
      final prefix = text.substring(wordStart, cursor).toLowerCase();

      // Filter matches.
      _tabMatches = completionsFor(words, prefix);
      if (_tabMatches.isEmpty) return;

      _tabPrefix = prefix;
      _tabInsertStart = wordStart;
      _tabCycleIndex = 0;
    } else {
      // Cycle to next match.
      _tabCycleIndex = (_tabCycleIndex + 1) % _tabMatches.length;
    }

    final match = _tabMatches[_tabCycleIndex];
    final text = _controller.text;
    // Find end of current completed word (from insert start to next space or end).
    final afterInsert = text.substring(_tabInsertStart);
    final spaceIdx = afterInsert.indexOf(' ');
    final wordEnd = spaceIdx < 0
        ? text.length
        : _tabInsertStart + spaceIdx;

    final newText = text.substring(0, _tabInsertStart) +
        match +
        text.substring(wordEnd);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: _tabInsertStart + match.length,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Ctrl/Cmd+1/2/3 to switch social tabs.
    final ctrlOrCmd = HardwareKeyboard.instance.logicalKeysPressed.any((k) =>
        k == LogicalKeyboardKey.controlLeft ||
        k == LogicalKeyboardKey.controlRight ||
        k == LogicalKeyboardKey.metaLeft ||
        k == LogicalKeyboardKey.metaRight);
    if (ctrlOrCmd) {
      int? tabIndex;
      if (event.logicalKey == LogicalKeyboardKey.digit1) tabIndex = 0;
      if (event.logicalKey == LogicalKeyboardKey.digit2) tabIndex = 1;
      if (event.logicalKey == LogicalKeyboardKey.digit3) tabIndex = 2;
      if (tabIndex != null) {
        final panelState = ref.read(socialPanelProvider);
        if (panelState.tabMode == PanelTabMode.tabbed) {
          ref.read(socialPanelProvider.notifier).setActiveTab(tabIndex);
        }
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _handleTab();
      return KeyEventResult.handled;
    }

    // Any non-TAB key resets completion state.
    _resetTabCompletion();

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _controller.clear();
      _resetHistorySearch();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _historyUp();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _historyDown();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _send();
      return KeyEventResult.handled;
    }

    // Any other key resets history search — user is typing new input.
    _resetHistorySearch();

    return KeyEventResult.ignored;
  }

  Widget _buildTextField(double fontSize, int wrapWidth, bool autofocus) {
    final mib = ref.watch(settingsProvider.select((s) => s.mobileInput));
    final textField = Focus(
      onKeyEvent: _handleKey,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: autofocus,
        maxLines: 1,
        autocorrect: mib.autocorrect,
        enableSuggestions: mib.enableSuggestions,
        smartDashesType: mib.smartDashesType,
        smartQuotesType: mib.smartQuotesType,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: fontSize,
        ),
        decoration: const InputDecoration(
          hintText: 'Enter command...',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          filled: false,
        ),
        // Soft-keyboard input doesn't route through _onKeyEvent, so the
        // history walk has to be reset here instead. Programmatic
        // controller updates (e.g. _historyUp) don't fire onChanged, so
        // walking the chip back and forth stays consistent.
        onChanged: (_) => _resetHistorySearch(),
        onSubmitted: (_) => _send(),
      ),
    );

    if (wrapWidth <= 0) return textField;

    // Constrain width so Flutter's word-wrap breaks lines at ~N characters.
    final charWidth = _measureCharWidth(fontSize);
    // Add small padding to avoid premature wrapping.
    final maxWidth = charWidth * wrapWidth + 8;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: textField,
      ),
    );
  }

  /// Measures the width of a single monospace character at the given font size.
  double _measureCharWidth(double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'X',
        style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final fontSize = settings.fontSize;
    final wrapWidth = settings.inputWrapWidth;
    final autofocus = !_shouldHideKeyboard(settings);

    // When the login dialog closes (character chosen, guest, or cancel),
    // move keyboard focus here — the input bar is where the user drives the
    // game from. Deferred one frame so the dialog is gone and its focus
    // released first. Skipped when mobile keyboard-hiding is on, so we don't
    // pop the soft keyboard against the user's preference.
    ref.listen(loginProvider, (prev, next) {
      if (prev is LoginPromptDetected && next is! LoginPromptDetected) {
        if (_shouldHideKeyboard(ref.read(settingsProvider))) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      }
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withAlpha(60),
          ),
        ),
      ),
      child: Row(
        children: [
          // History button — opens a sheet with the last few commands plus
          // smart counterparts (enter↔leave, open/close ↔ opposite door).
          // Tap an entry to re-send instantly. Replaces the old up-arrow
          // chip on the right; keyboard ArrowUp still walks history for
          // desktop users.
          IconButton(
            icon: Icon(
              Icons.history,
              color: theme.colorScheme.primary.withAlpha(200),
            ),
            onPressed: _showHistorySheet,
            tooltip: 'Recent commands',
            visualDensity: VisualDensity.compact,
          ),

          // Command prompt indicator.
          Text(
            '>',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: fontSize + 2,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),

          // Text input field.
          Expanded(
            child: _buildTextField(fontSize, wrapWidth, autofocus),
          ),

          // Send button (mainly for mobile).
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: theme.colorScheme.primary,
            ),
            onPressed: _send,
            tooltip: 'Send command',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _showHistorySheet() async {
    final history = ref.read(commandHistoryProvider);
    final recent = history.take(5).toList();
    // Counterparts derived from the same recent commands. Dedup against
    // history so the user doesn't see "leave" twice when both legs are
    // already in history.
    final counterparts = <String>{};
    for (final cmd in recent) {
      counterparts.addAll(CommandCounterparts.counterpartsOf(cmd));
    }
    counterparts.removeAll(recent);

    if (recent.isEmpty && counterparts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No command history yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _HistorySheet(
        recent: recent,
        counterparts: counterparts.toList(),
      ),
    );

    if (chosen == null || !mounted) return;
    _sendCommandFromHistory(chosen);
  }

  /// Sends a command picked from the history sheet. Doesn't expand aliases
  /// further (the history already stores the user's typed input, which the
  /// regular send path will expand if appropriate via [_controller]).
  void _sendCommandFromHistory(String command) {
    _controller.text = command;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _send();
  }
}

/// Bottom-sheet body for the History button. Two sections: literal recent
/// commands (newest-first) and derived counterparts. Tapping a row pops
/// the sheet with that command string.
class _HistorySheet extends StatelessWidget {
  final List<String> recent;
  final List<String> counterparts;

  const _HistorySheet({required this.recent, required this.counterparts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (recent.isNotEmpty) ...[
              _SectionLabel(
                icon: Icons.history,
                label: 'Recent',
                theme: theme,
              ),
              for (final cmd in recent)
                _CommandRow(command: cmd, theme: theme),
            ],
            if (counterparts.isNotEmpty) ...[
              const Divider(height: 16),
              _SectionLabel(
                icon: Icons.swap_horiz,
                label: 'Counterparts',
                theme: theme,
              ),
              for (final cmd in counterparts)
                _CommandRow(
                  command: cmd,
                  theme: theme,
                  trailing: const Icon(Icons.subdirectory_arrow_right,
                      size: 18),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  final String command;
  final ThemeData theme;
  final Widget? trailing;

  const _CommandRow({
    required this.command,
    required this.theme,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(command),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                command,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                ),
              ),
            ),
            if (trailing != null)
              IconTheme(
                data: IconThemeData(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
                child: trailing!,
              ),
          ],
        ),
      ),
    );
  }
}
