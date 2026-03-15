import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/social_message.dart';
import '../../../providers/social_message_provider.dart';

/// Which buffer to display.
enum SocialListType { chat, tells }

/// Scrollable list of social messages with auto-scroll.
class SocialMessageList extends ConsumerStatefulWidget {
  final SocialListType type;

  const SocialMessageList({super.key, required this.type});

  @override
  ConsumerState<SocialMessageList> createState() => _SocialMessageListState();
}

class _SocialMessageListState extends ConsumerState<SocialMessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Scroll to bottom on initial build (e.g. after tab switch).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    _autoScroll = pos.pixels >= pos.maxScrollExtent - 20;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.type == SocialListType.chat
        ? ref.watch(chatMessagesProvider)
        : ref.watch(tellMessagesProvider);

    // Auto-scroll when new messages arrive.
    ref.listen(
      widget.type == SocialListType.chat
          ? chatMessagesProvider
          : tellMessagesProvider,
      (previous, next) {
        if (_autoScroll && next.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      },
    );

    if (messages.isEmpty) {
      return Center(
        child: Text(
          widget.type == SocialListType.chat
              ? 'No chat messages yet'
              : 'No tells yet',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(80),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: messages.length,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      itemBuilder: (context, index) {
        return _MessageWidget(message: messages[index]);
      },
    );
  }
}

class _MessageWidget extends StatelessWidget {
  final SocialMessage message;

  const _MessageWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build a list of TextSpans from all styled lines in this message.
    const fontFamily = 'JetBrainsMono';
    const fontSize = 13.0;
    final children = <InlineSpan>[];
    for (var i = 0; i < message.styledLines.length; i++) {
      if (i > 0) {
        children.add(const TextSpan(text: '\n'));
      }
      children.add(message.styledLines[i].toTextSpan(
        fontFamily: fontFamily,
        fontSize: fontSize,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp.
          Text(
            '${message.timestamp.hour.toString().padLeft(2, '0')}:'
            '${message.timestamp.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              color: theme.colorScheme.onSurface.withAlpha(60),
            ),
          ),
          const SizedBox(width: 4),
          // Message content.
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                ),
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
