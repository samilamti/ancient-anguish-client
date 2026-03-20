import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/social_message.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/social_message_provider.dart';

/// Which buffer to display.
enum SocialListType { chat, tells }

/// Scrollable list of social messages with auto-scroll and lazy display.
///
/// Initially shows the most recent [_initialDisplay] messages. When the user
/// scrolls to the top, older messages are loaded in batches of [_batchSize].
class SocialMessageList extends ConsumerStatefulWidget {
  final SocialListType type;

  const SocialMessageList({super.key, required this.type});

  @override
  ConsumerState<SocialMessageList> createState() => _SocialMessageListState();
}

class _SocialMessageListState extends ConsumerState<SocialMessageList> {
  static const int _initialDisplay = 50;
  static const int _batchSize = 50;

  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  int _displayCount = _initialDisplay;

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

    // Load more messages when scrolled to the top.
    if (pos.pixels <= 0) {
      _loadMore();
    }
  }

  void _loadMore() {
    final totalMessages = _currentMessages.length;
    if (_displayCount >= totalMessages) return;

    final prevMax = _scrollController.position.maxScrollExtent;
    setState(() {
      _displayCount = min(_displayCount + _batchSize, totalMessages);
    });

    // Preserve scroll position after inserting older messages above.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final newMax = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(newMax - prevMax);
      }
    });
  }

  List<SocialMessage> get _currentMessages =>
      widget.type == SocialListType.chat
          ? ref.read(chatMessagesProvider)
          : ref.read(tellMessagesProvider);

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontSize = ref.watch(settingsProvider).fontSize - 1;
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
          // Grow display count to include the new message.
          if (_displayCount < next.length) {
            _displayCount = min(_displayCount + 1, next.length);
          }
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
            fontSize: fontSize,
            color: theme.colorScheme.onSurface.withAlpha(80),
          ),
        ),
      );
    }

    // Show only the most recent _displayCount messages.
    final start = messages.length > _displayCount
        ? messages.length - _displayCount
        : 0;
    final displayed = messages.sublist(start);
    final hasMore = start > 0;

    return ListView.builder(
      controller: _scrollController,
      itemCount: displayed.length + (hasMore ? 1 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      itemBuilder: (context, index) {
        // "Load more" indicator at the top.
        if (hasMore && index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Text(
                'Scroll up for older messages ($start more)',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: fontSize - 3,
                  color: theme.colorScheme.onSurface.withAlpha(60),
                ),
              ),
            ),
          );
        }
        final msgIndex = hasMore ? index - 1 : index;
        return _MessageWidget(
          message: displayed[msgIndex],
          isEven: msgIndex.isEven,
          fontSize: fontSize,
        );
      },
    );
  }
}

class _MessageWidget extends StatelessWidget {
  final SocialMessage message;
  final bool isEven;
  final double fontSize;

  const _MessageWidget({
    required this.message,
    required this.isEven,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build a list of TextSpans from all styled lines in this message.
    const fontFamily = 'JetBrainsMono';
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
      decoration: isEven
          ? BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(10),
              borderRadius: BorderRadius.circular(2),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp.
          Text(
            '${message.timestamp.hour.toString().padLeft(2, '0')}:'
            '${message.timestamp.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: fontSize - 3,
              color: theme.colorScheme.onSurface.withAlpha(60),
            ),
          ),
          const SizedBox(width: 4),
          // Message content.
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: fontSize,
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
