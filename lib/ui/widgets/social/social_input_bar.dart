import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connection_provider.dart'
    show connectionServiceProvider;
import '../../../providers/settings_provider.dart';
import '../../../providers/social_input_provider.dart';
import '../../../providers/social_message_provider.dart';
import '../../../services/parser/emoji_parser.dart';
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
    final settings = ref.read(settingsProvider);
    final outText = settings.emojiParsingEnabled
        ? EmojiParser.reverseEmojis(text)
        : text;

    if (widget.type == SocialListType.chat) {
      service.sendCommand('chat $outText');
      ref.read(chatHistoryProvider.notifier).add(text);
    } else {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        // Focus the name field if no recipient.
        _nameFocusNode.requestFocus();
        return;
      }
      service.sendCommand('tell $name $outText');
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

          // Recipient name field with autocomplete (tells only).
          if (widget.type == SocialListType.tells) ...[
            SizedBox(
              width: 140,
              child: RawAutocomplete<String>(
                textEditingController: _nameController,
                focusNode: _nameFocusNode,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final partners = ref.read(recentTellPartnersProvider);
                  if (partners.isEmpty) return const Iterable<String>.empty();
                  final text = textEditingValue.text.toLowerCase();
                  if (text.isEmpty) return partners;
                  return partners.where(
                    (name) => name.toLowerCase().startsWith(text),
                  );
                },
                onSelected: (String selection) {
                  _nameController.text = selection;
                  _nameController.selection = TextSelection.collapsed(
                    offset: selection.length,
                  );
                  ref
                      .read(tellMessagesProvider.notifier)
                      .setLastRecipient(selection);
                  _focusNode.requestFocus();
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
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
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 6),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          if (!focusNode.hasFocus) {
                            focusNode.requestFocus();
                          }
                          // Trigger options rebuild.
                          controller.selection = TextSelection.collapsed(
                            offset: controller.text.length,
                          );
                        },
                        child: Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: primary.withAlpha(140),
                        ),
                      ),
                      suffixIconConstraints:
                          const BoxConstraints(maxWidth: 20, maxHeight: 24),
                    ),
                    onSubmitted: (_) => _focusNode.requestFocus(),
                    textInputAction: TextInputAction.next,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(4),
                      color: theme.colorScheme.surface,
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxHeight: 200, maxWidth: 160),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final name = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(name),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 4),
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
