import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_message.dart';
import '../protocol/ansi/styled_span.dart';

/// Chat message buffer.
final chatMessagesProvider =
    NotifierProvider<ChatMessagesNotifier, List<SocialMessage>>(
        ChatMessagesNotifier.new);

/// Manages the chat message buffer.
class ChatMessagesNotifier extends Notifier<List<SocialMessage>> {
  static const int _maxMessages = 500;

  @override
  List<SocialMessage> build() => [];

  /// Adds a complete chat message.
  void addMessage(SocialMessage message) {
    final newState = [...state, message];
    if (newState.length > _maxMessages) {
      state = newState.sublist(newState.length - _maxMessages);
    } else {
      state = newState;
    }
  }

  /// Appends continuation text to the most recent message.
  void appendContinuation(StyledLine styledLine, String plainText) {
    if (state.isEmpty) return;
    final updated = List<SocialMessage>.from(state);
    updated[updated.length - 1] =
        updated.last.withContinuation(styledLine, plainText);
    state = updated;
  }

  void clear() => state = [];
}

/// Tell message buffer.
final tellMessagesProvider =
    NotifierProvider<TellMessagesNotifier, List<SocialMessage>>(
        TellMessagesNotifier.new);

/// Manages the tell message buffer and tracks the last recipient.
class TellMessagesNotifier extends Notifier<List<SocialMessage>> {
  static const int _maxMessages = 500;
  String? _lastRecipient;

  /// Most recent tell recipient for quick-reply.
  String? get lastRecipient => _lastRecipient;

  @override
  List<SocialMessage> build() {
    _lastRecipient = null;
    return [];
  }

  /// Adds a complete tell message.
  void addMessage(SocialMessage message) {
    final newState = [...state, message];
    if (newState.length > _maxMessages) {
      state = newState.sublist(newState.length - _maxMessages);
    } else {
      state = newState;
    }
  }

  /// Appends continuation text to the most recent message.
  void appendContinuation(StyledLine styledLine, String plainText) {
    if (state.isEmpty) return;
    final updated = List<SocialMessage>.from(state);
    updated[updated.length - 1] =
        updated.last.withContinuation(styledLine, plainText);
    state = updated;
  }

  /// Sets the last tell recipient (for quick-reply).
  void setLastRecipient(String name) => _lastRecipient = name;

  /// Clears the last recipient.
  void clearRecipient() => _lastRecipient = null;

  void clear() {
    _lastRecipient = null;
    state = [];
  }
}

/// Provides the last tell recipient as a watchable provider.
final lastTellRecipientProvider = Provider<String?>((ref) {
  // Force a dependency on tellMessagesProvider so this updates.
  ref.watch(tellMessagesProvider);
  return ref.read(tellMessagesProvider.notifier).lastRecipient;
});
