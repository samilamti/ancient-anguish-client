import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/recent_words_provider.dart';

void main() {
  group('completionsFor', () {
    test('empty prefix returns all words', () {
      final result = completionsFor(['rabbit', 'orc', 'goblin'], '');
      expect(result, ['rabbit', 'orc', 'goblin']);
    });

    test('prefix matches case-insensitively', () {
      final result = completionsFor(['rabbit', 'orc', 'goblin', 'rat'], 'R');
      expect(result, ['rabbit', 'rat']);
    });

    test('returns empty list when no matches', () {
      final result = completionsFor(['rabbit', 'orc'], 'zzz');
      expect(result, isEmpty);
    });

    test('preserves input order', () {
      final result = completionsFor(['gnoll', 'goblin', 'giant'], 'g');
      expect(result, ['gnoll', 'goblin', 'giant']);
    });

    test('returns unmodifiable list for empty prefix', () {
      final result = completionsFor(['a', 'b'], '');
      expect(() => result.add('c'), throwsUnsupportedError);
    });

    test('empty words list yields empty result regardless of prefix', () {
      expect(completionsFor(const [], ''), isEmpty);
      expect(completionsFor(const [], 'anything'), isEmpty);
    });
  });
}
