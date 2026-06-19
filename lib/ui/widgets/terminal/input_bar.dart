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
import '../../../providers/completion_rules_provider.dart';
import '../../../providers/recent_words_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/social_panel_provider.dart';
import '../../../models/social_panel_state.dart';
import '../../screens/alias_settings_screen.dart' show openAliasEditor;
import '../../../models/alias_rule.dart';
import '../../../services/alias/alias_command.dart';
import '../../../services/command_counterparts.dart';
import '../../../services/command_loops.dart';
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

  /// How many recent commands the History ("Recent commands") sheet lists.
  /// Desktop has far more vertical room, so it shows the full retained history
  /// (capped at [CommandHistoryService.maxEntries] = 20); mobile stays compact.
  static const int _recentSheetCountMobile = 8;
  static const int _recentSheetCountDesktop = 20;

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

    // Quick alias creation: `#al <alias> <expansion>`. Handled entirely
    // client-side and intercepted *before* alias expansion so semicolons in
    // the expansion are stored verbatim rather than split into commands.
    final aliasCommand = AliasCommand.parse(command);
    if (aliasCommand != null) {
      _handleAliasCommand(aliasCommand, command);
      return;
    }

    final service = ref.read(connectionServiceProvider);
    final history = ref.read(commandHistoryProvider.notifier);
    final aliasEngine = ref.read(aliasEngineProvider);

    // Expand aliases — may produce multiple commands (semicolons).
    final expanded = aliasEngine.expand(command);
    final settings = ref.read(settingsProvider);
    // Break commands (e.g. `breakdo`) to drop into history after a loop
    // command like `dotimes` is sent. Collected as a set so a multi-command
    // line adds each break command only once.
    final breakCommands = <String>{};
    for (final cmd in expanded) {
      // Suppress emoji parsing for map output so ASCII art renders cleanly.
      if (cmd.trim().toLowerCase() == 'read map') {
        ref.read(terminalBufferProvider.notifier).suppressEmojiUntilPrompt();
      }
      final breakCmd = CommandLoops.breakCommandFor(cmd);
      if (breakCmd != null) breakCommands.add(breakCmd);
      final outgoing = settings.emojiParsingEnabled
          ? EmojiParser.reverseEmojis(cmd)
          : cmd;
      service.sendCommand(outgoing);
    }
    history.add(command);
    // After the sent command, add any loop-break commands so they become the
    // most-recent history entries — one Up-arrow recalls `breakdo`. Added to
    // history only; never sent automatically.
    for (final breakCmd in breakCommands) {
      history.add(breakCmd);
    }
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

  /// Creates (or updates) an alias from a parsed `#al` command and echoes
  /// local confirmation into the terminal. Never sends anything to the MUD.
  void _handleAliasCommand(AliasCommand cmd, String raw) {
    final buffer = ref.read(terminalBufferProvider.notifier);

    if (!cmd.isValid) {
      buffer.addLocalLine(cmd.error!, isError: true);
    } else {
      final keyword = cmd.keyword!;
      final expansion = cmd.expansion!;
      final notifier = ref.read(aliasRulesProvider.notifier);

      // Overwrite an existing alias with the same keyword rather than create
      // a duplicate (keeps the keyword unambiguous for the engine).
      AliasRule? existing;
      for (final rule in ref.read(aliasRulesProvider)) {
        if (rule.keyword == keyword) {
          existing = rule;
          break;
        }
      }

      if (existing != null) {
        notifier.updateRule(
          existing.copyWith(expansion: expansion, enabled: true),
        );
        buffer.addLocalLine('Alias updated: $keyword → $expansion');
      } else {
        notifier.addRule(AliasRule(
          id: 'alias_${DateTime.now().millisecondsSinceEpoch}',
          keyword: keyword,
          expansion: expansion,
        ));
        buffer.addLocalLine('Alias created: $keyword → $expansion');
      }
    }

    // Keep the raw `#al ...` line in history so it can be recalled/edited,
    // then reselect the input for a quick follow-up.
    ref.read(commandHistoryProvider.notifier).add(raw);
    _resetHistorySearch();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _focusNode.requestFocus();
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

  /// Accepts a mobile auto-completion suggestion: replaces the input with
  /// [completion] (trailing space preserved), parks the cursor at the end, and
  /// keeps focus so the user can keep typing — mirroring desktop TAB accept.
  void _applyCompletion(String completion) {
    _resetTabCompletion();
    _resetHistorySearch();
    _controller.text = completion;
    _controller.selection = TextSelection.collapsed(offset: completion.length);
    _focusNode.requestFocus();
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
    final isMobile = MediaQuery.of(context).size.width < 768;

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

    final inputBar = Container(
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

    // Desktop drives completion via the TAB key; mobile gets a tappable
    // suggestion bar above the input instead.
    if (!isMobile) return inputBar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSuggestionBar(theme, fontSize),
        inputBar,
      ],
    );
  }

  /// A horizontal bar of tappable completion suggestions shown above the input
  /// on mobile. Mirrors desktop TAB completion: when the typed text matches a
  /// rule trigger, tapping a chip fills the completion. Renders nothing when
  /// there is no match, so it takes no space.
  Widget _buildSuggestionBar(ThemeData theme, double fontSize) {
    final rules = ref.watch(completionRulesProvider);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final matches = matchCompletions(rules, value.text);
        if (matches.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in matches)
                  _CompletionChip(
                    label: m.completion,
                    fontSize: fontSize,
                    theme: theme,
                    onTap: () => _applyCompletion(m.completion),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showHistorySheet() async {
    final history = ref.read(commandHistoryProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final count =
        isMobile ? _recentSheetCountMobile : _recentSheetCountDesktop;
    final recent = history.take(count).toList();
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

    final chosen = await showModalBottomSheet<_HistoryChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _HistorySheet(
        recent: recent,
        counterparts: counterparts.toList(),
      ),
    );

    if (chosen == null || !mounted) return;
    if (chosen.intent == _HistoryIntent.makeAlias) {
      // Turn the picked command into a new alias, pre-filling its expansion.
      openAliasEditor(context, initialExpansion: chosen.command);
    } else {
      _sendCommandFromHistory(chosen.command);
    }
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

/// What the user picked in the Recent-commands sheet: either re-send the
/// command, or open the alias editor pre-filled with it as the expansion.
enum _HistoryIntent { send, makeAlias }

class _HistoryChoice {
  final String command;
  final _HistoryIntent intent;
  const _HistoryChoice(this.command, this.intent);
}

/// Bottom-sheet body for the History button. Two sections: literal recent
/// commands (newest-first) and derived counterparts. Tapping a row's body
/// pops the sheet to send that command; tapping its "+" pops to make an alias.
/// Scrollable so the longer desktop list can't overflow the sheet.
class _HistorySheet extends StatelessWidget {
  final List<String> recent;
  final List<String> counterparts;

  const _HistorySheet({required this.recent, required this.counterparts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      // Cap the sheet at ~60% of the window so the longer desktop list scrolls
      // instead of pushing past the screen; shorter lists shrink-wrap.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
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
                  isCounterpart: true,
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

  /// Marks a derived "counterpart" row: shows a trailing ↳ hint and no alias
  /// button (only literal recent commands can be turned into aliases).
  final bool isCounterpart;

  const _CommandRow({
    required this.command,
    required this.theme,
    this.isCounterpart = false,
  });

  @override
  Widget build(BuildContext context) {
    // Counterparts just mark themselves with a ↳; recent commands get a "+"
    // that opens the alias editor pre-filled with the command as the expansion.
    final Widget trailing = isCounterpart
        ? Icon(
            Icons.subdirectory_arrow_right,
            size: 18,
            color: theme.colorScheme.onSurface.withAlpha(120),
          )
        : IconButton(
            icon: const Icon(Icons.add, size: 20),
            color: theme.colorScheme.primary,
            tooltip: 'Create alias from this command',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context)
                .pop(_HistoryChoice(command, _HistoryIntent.makeAlias)),
          );

    return InkWell(
      onTap: () => Navigator.of(context)
          .pop(_HistoryChoice(command, _HistoryIntent.send)),
      child: Padding(
        // Recent rows get their height from the "+" IconButton; counterpart
        // rows have only a plain icon, so pad them to a comparable height.
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: isCounterpart ? 12 : 4,
        ),
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
            trailing,
          ],
        ),
      ),
    );
  }
}

/// A tappable pill in the mobile auto-completion bar. Shows the completion
/// text (trailing space trimmed for display) behind a small accept icon;
/// tapping fills the full completion into the input.
class _CompletionChip extends StatelessWidget {
  final String label;
  final double fontSize;
  final ThemeData theme;
  final VoidCallback onTap;

  const _CompletionChip({
    required this.label,
    required this.fontSize,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.primary.withAlpha(30),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_tab,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label.trimRight(),
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: fontSize - 1,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
