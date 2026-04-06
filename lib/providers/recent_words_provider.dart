import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maintains an ordered list of recently seen capitalized words from MUD output,
/// stored as lowercase for case-insensitive TAB completion.
class RecentWordsNotifier extends Notifier<List<String>> {
  static const int maxWords = 200;

  @override
  List<String> build() => [];

  /// Extracts words (3+ chars) from a line and adds them
  /// to the front of the list as lowercase, sorted by recency.
  void extractFromLine(String plainText) {
    final matches = RegExp(r'\b[a-zA-Z]{3,}\b').allMatches(plainText);
    if (matches.isEmpty) return;

    var updated = [...state];
    for (final match in matches) {
      final word = match.group(0)!.toLowerCase();
      updated.remove(word);
      updated.insert(0, word);
    }
    if (updated.length > maxWords) {
      updated = updated.sublist(0, maxWords);
    }
    state = updated;
  }
}

final recentWordsProvider =
    NotifierProvider<RecentWordsNotifier, List<String>>(
  RecentWordsNotifier.new,
);
