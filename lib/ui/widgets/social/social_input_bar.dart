import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connection_provider.dart'
    show connectionServiceProvider;
import '../../../providers/social_input_provider.dart';
import '../../../providers/social_message_provider.dart';
import 'social_message_list.dart';

/// Input bar for social windows (Chat or Tell).
///
/// Chat: Prefix "[Chat]", sends `chat` followed by the message.
/// Tell: Prefix "[Tell]" + name field, sends `tell name message`.
///   - Name auto-populated from most recent incoming tell.
///   - ESC clears the name field.
class SocialInputBar extends ConsumerStatefulWidget {
  final SocialListType type;

  const SocialInputBar({super.key, required this.type});

  @override
  ConsumerState<SocialInputBar> createState() => _SocialInputBarState();
}

class _SocialInputBarState extends ConsumerState<SocialInputBar> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _focusNode.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final service = ref.read(connectionServiceProvider);

    if (widget.type == SocialListType.chat) {
      service.sendCommand('chat $text');
      ref.read(chatHistoryProvider.notifier).add(text);
    } else {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        // Focus the name field if no recipient.
        _nameFocusNode.requestFocus();
        return;
      }
      service.sendCommand('tell $name $text');
      ref.read(tellHistoryProvider.notifier).add(text);
      ref.read(tellMessagesProvider.notifier).setLastRecipient(name);
    }
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _historyUp() {
    final history = widget.type == SocialListType.chat
        ? ref.read(chatHistoryProvider.notifier)
        : ref.read(tellHistoryProvider.notifier);
    final previous = history.previous();
    if (previous != null) {
      _controller.text = previous;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  void _historyDown() {
    final history = widget.type == SocialListType.chat
        ? ref.read(chatHistoryProvider.notifier)
        : ref.read(tellHistoryProvider.notifier);
    final next = history.next();
    if (next != null) {
      _controller.text = next;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.type == SocialListType.tells) {
        _nameController.clear();
        ref.read(tellMessagesProvider.notifier).clearRecipient();
      }
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
    final primary = theme.colorScheme.primary;

    // Auto-populate recipient from last tell.
    if (widget.type == SocialListType.tells) {
      final lastRecipient = ref.watch(lastTellRecipientProvider);
      if (lastRecipient != null && _nameController.text.isEmpty) {
        _nameController.text = lastRecipient;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: primary.withAlpha(40)),
        ),
      ),
      child: Row(
        children: [
          // Prefix label.
          Text(
            widget.type == SocialListType.chat ? '[Chat]' : '[Tell]',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: primary.withAlpha(160),
            ),
          ),
          const SizedBox(width: 4),

          // Recipient name field (tells only).
          if (widget.type == SocialListType.tells) ...[
            SizedBox(
              width: 80,
              child: TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: primary,
                ),
                decoration: InputDecoration(
                  hintText: 'name',
                  hintStyle: TextStyle(
                    fontSize: 11,
                    color: primary.withAlpha(60),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
                onSubmitted: (_) => _focusNode.requestFocus(),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 2),
          ],

          // Message input.
          Expanded(
            child: Focus(
              onKeyEvent: _handleKey,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: widget.type == SocialListType.chat
                      ? 'Chat message...'
                      : 'Tell message...',
                  hintStyle: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withAlpha(60),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),

          // Send button.
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              icon: Icon(Icons.send_rounded, size: 14, color: primary),
              onPressed: _send,
              tooltip: 'Send',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
