import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Command history for the chat input.
final chatHistoryProvider =
    NotifierProvider<SocialHistoryNotifier, List<String>>(
        SocialHistoryNotifier.new);

/// Command history for the party input.
final partyHistoryProvider =
    NotifierProvider<SocialHistoryNotifier, List<String>>(
        SocialHistoryNotifier.new);

/// Command history for the tell input.
final tellHistoryProvider =
    NotifierProvider<SocialHistoryNotifier, List<String>>(
        SocialHistoryNotifier.new);

/// Manages command history for a social input bar.
class SocialHistoryNotifier extends Notifier<List<String>> {
  static const int _maxHistory = 100;
  int _position = -1;

  @override
  List<String> build() => [];

  /// Adds a command to history (most recent first).
  void add(String command) {
    if (command.trim().isEmpty) return;
    if (state.isNotEmpty && state.first == command) {
      _position = -1;
      return;
    }
    final newState = [command, ...state];
    if (newState.length > _maxHistory) {
      state = newState.sublist(0, _maxHistory);
    } else {
      state = newState;
    }
    _position = -1;
  }

  /// Navigates backward (older) in history.
  String? previous() {
    if (state.isEmpty) return null;
    if (_position < state.length - 1) _position++;
    return state[_position];
  }

  /// Navigates forward (newer) in history.
  String? next() {
    if (_position <= 0) {
      _position = -1;
      return '';
    }
    _position--;
    return state[_position];
  }

  void resetPosition() => _position = -1;
}
