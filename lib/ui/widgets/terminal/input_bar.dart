import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/alias_provider.dart';
import '../../../providers/connection_provider.dart'
    show connectionServiceProvider, commandHistoryProvider, inputFocusProvider;
import '../../../providers/settings_provider.dart';
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
    // Select all text so the user can resend with Enter or type to replace.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );

    // Keep focus on input after sending.
    _focusNode.requestFocus();
  }

  void _historyUp() {
    final history = ref.read(commandHistoryProvider.notifier);
    final previous = history.previous();
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

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _controller.clear();
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

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              fontSize: 16,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),

          // Text input field.
          Expanded(
            child: Focus(
              onKeyEvent: _handleKey,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter command...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  filled: false,
                ),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
              ),
            ),
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
