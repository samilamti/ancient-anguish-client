import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/alias_provider.dart';
import '../../../providers/connection_provider.dart'
    show connectionServiceProvider, commandHistoryProvider, inputFocusProvider,
    terminalBufferProvider;
import '../../../providers/game_state_provider.dart';
import '../../../providers/recent_words_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/terminal_block_provider.dart';
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
  final TextEditingController _controller = TextEditingController();
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
    _controller.dispose();
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
      final outgoing = settings.emojiParsingEnabled
          ? EmojiParser.reverseEmojis(cmd)
          : cmd;
      service.sendCommand(outgoing);
    }
    history.add(command);
    _resetHistorySearch();
    ref.read(gameStateProvider.notifier).recordDirectionalAttempt(command);
    // Emit a command boundary for block mode.
    if (settings.blockModeEnabled) {
      ref
          .read(blockBoundaryProvider.notifier)
          .markCommandBoundary(ref.read(terminalBufferProvider).length);
    }
    // Select all text so the user can resend with Enter or type to replace.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );

    // Keep focus on input after sending.
    _focusNode.requestFocus();
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
      _tabMatches = prefix.isEmpty
          ? words
          : words.where((w) => w.startsWith(prefix)).toList();
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

  Widget _buildTextField(double fontSize, int wrapWidth) {
    final textField = Focus(
      onKeyEvent: _handleKey,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        maxLines: 1,
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
            child: _buildTextField(fontSize, wrapWidth),
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
}
