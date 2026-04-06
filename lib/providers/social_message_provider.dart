import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_message.dart';
import '../protocol/ansi/styled_span.dart';
import '../services/social/social_history_service.dart';
import '../services/storage/storage_service.dart';
import 'storage_provider.dart';

/// Chat message buffer.
final chatMessagesProvider =
    NotifierProvider<ChatMessagesNotifier, List<SocialMessage>>(
        ChatMessagesNotifier.new);

/// Manages the chat message buffer with disk persistence.
class ChatMessagesNotifier extends Notifier<List<SocialMessage>> {
  static const int _maxMessages = 500;

  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  List<SocialMessage> build() {
    _loadFromDisk();
    return [];
  }

  Future<void> _loadFromDisk() async {
    try {
      final messages = await SocialHistoryService.loadChat(_storage);
      if (messages.isNotEmpty) {
        state = messages.length > _maxMessages
            ? messages.sublist(messages.length - _maxMessages)
            : messages;
      }
    } catch (e) {
      debugPrint('ChatMessagesNotifier._loadFromDisk: $e');
    }
  }

  /// Adds a complete chat message.
  void addMessage(SocialMessage message) {
    final newState = [...state, message];
    if (newState.length > _maxMessages) {
      state = newState.sublist(newState.length - _maxMessages);
    } else {
      state = newState;
    }
    SocialHistoryService.appendMessage(_storage, message, isChat: true);
  }

  /// Appends continuation text to the most recent message.
  void appendContinuation(StyledLine styledLine, String plainText) {
    if (state.isEmpty) return;
    final updated = List<SocialMessage>.from(state);
    updated[updated.length - 1] =
        updated.last.withContinuation(styledLine, plainText);
    state = updated;
    SocialHistoryService.appendContinuation(_storage, plainText, isChat: true);
  }

  void clear() => state = [];
}

/// Party message buffer.
final partyMessagesProvider =
    NotifierProvider<PartyMessagesNotifier, List<SocialMessage>>(
        PartyMessagesNotifier.new);

/// Manages the party message buffer with disk persistence.
class PartyMessagesNotifier extends Notifier<List<SocialMessage>> {
  static const int _maxMessages = 500;

  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  List<SocialMessage> build() {
    _loadFromDisk();
    return [];
  }

  Future<void> _loadFromDisk() async {
    try {
      final messages = await SocialHistoryService.loadParty(_storage);
      if (messages.isNotEmpty) {
        state = messages.length > _maxMessages
            ? messages.sublist(messages.length - _maxMessages)
            : messages;
      }
    } catch (e) {
      debugPrint('PartyMessagesNotifier._loadFromDisk: $e');
    }
  }

  void addMessage(SocialMessage message) {
    final newState = [...state, message];
    if (newState.length > _maxMessages) {
      state = newState.sublist(newState.length - _maxMessages);
    } else {
      state = newState;
    }
    SocialHistoryService.appendPartyMessage(_storage, message);
  }

  void appendContinuation(StyledLine styledLine, String plainText) {
    if (state.isEmpty) return;
    final updated = List<SocialMessage>.from(state);
    updated[updated.length - 1] =
        updated.last.withContinuation(styledLine, plainText);
    state = updated;
    SocialHistoryService.appendPartyContinuation(_storage, plainText);
  }

  void clear() => state = [];
}

/// Tell message buffer.
final tellMessagesProvider =
    NotifierProvider<TellMessagesNotifier, List<SocialMessage>>(
        TellMessagesNotifier.new);

/// Manages the tell message buffer with disk persistence and tracks the last
/// recipient.
class TellMessagesNotifier extends Notifier<List<SocialMessage>> {
  static const int _maxMessages = 500;
  String? _lastRecipient;

  StorageService get _storage => ref.read(storageServiceProvider);

  /// Most recent tell recipient for quick-reply.
  String? get lastRecipient => _lastRecipient;

  @override
  List<SocialMessage> build() {
    _lastRecipient = null;
    _loadFromDisk();
    return [];
  }

  Future<void> _loadFromDisk() async {
    try {
      final messages = await SocialHistoryService.loadTells(_storage);
      if (messages.isNotEmpty) {
        state = messages.length > _maxMessages
            ? messages.sublist(messages.length - _maxMessages)
            : messages;
        // Populate last recipient from the most recent tell.
        _lastRecipient = messages.last.sender;
      }
    } catch (e) {
      debugPrint('TellMessagesNotifier._loadFromDisk: $e');
    }
  }

  /// Adds a complete tell message.
  void addMessage(SocialMessage message) {
    final newState = [...state, message];
    if (newState.length > _maxMessages) {
      state = newState.sublist(newState.length - _maxMessages);
    } else {
      state = newState;
    }
    SocialHistoryService.appendMessage(_storage, message, isChat: false);
  }

  /// Appends continuation text to the most recent message.
  void appendContinuation(StyledLine styledLine, String plainText) {
    if (state.isEmpty) return;
    final updated = List<SocialMessage>.from(state);
    updated[updated.length - 1] =
        updated.last.withContinuation(styledLine, plainText);
    state = updated;
    SocialHistoryService.appendContinuation(_storage, plainText, isChat: false);
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

/// Unique recent tell partner names, most-recent first. Max 20.
final recentTellPartnersProvider = Provider<List<String>>((ref) {
  final messages = ref.watch(tellMessagesProvider);
  final seen = <String>{};
  final partners = <String>[];
  for (var i = messages.length - 1; i >= 0; i--) {
    final name = messages[i].sender.toLowerCase();
    if (seen.add(name)) {
      partners.add(messages[i].sender);
      if (partners.length >= 20) break;
    }
  }
  return partners;
});
