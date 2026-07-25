import 'package:ancient_anguish_client/providers/completion_rules_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rules = kDefaultCompletionRules;
  const words = ['powerup', 'goblin', 'goblet', 'gorge', 'trunk', 'tower'];

  List<String> labels(List<CompletionHint> hints) =>
      hints.map((h) => h.label).toList();

  group('buildCompletionHints', () {
    test('returns nothing for empty input', () {
      expect(
        buildCompletionHints(rules: rules, recentWords: words, input: ''),
        isEmpty,
      );
    });

    test('rule triggers surface their completion', () {
      final hints =
          buildCompletionHints(rules: rules, recentWords: const [], input: 'po');
      expect(labels(hints), ['powerup']);
      expect(hints.single.resolvedInput, 'powerup');
      expect(hints.single.sendsOnTap, isTrue);
    });

    test('multi-word rule triggers still match', () {
      final hints = buildCompletionHints(
        rules: rules,
        recentWords: const [],
        input: 'i t',
      );
      expect(labels(hints), ['i trunk -c']);
      expect(hints.single.resolvedInput, 'i trunk -c');
    });

    test('a completion ending in a space is a partial template', () {
      final hints = buildCompletionHints(
        rules: rules,
        recentWords: const [],
        input: 'dot',
      );
      expect(hints.single.resolvedInput, 'dotimes 30 ');
      expect(hints.single.label, 'dotimes 30');
      expect(hints.single.sendsOnTap, isFalse);
    });

    test('recent words complete the word under the cursor', () {
      final hints = buildCompletionHints(
        rules: rules,
        recentWords: words,
        input: 'kill gob',
      );
      expect(labels(hints), ['goblin', 'goblet']);
      expect(hints.first.resolvedInput, 'kill goblin');
      expect(hints.first.sendsOnTap, isTrue);
    });

    test('the head of the line is preserved when splicing', () {
      final hints = buildCompletionHints(
        rules: rules,
        recentWords: words,
        input: 'get sword from tru',
      );
      expect(hints.single.resolvedInput, 'get sword from trunk');
    });

    test('a fully-typed word offers no hint of itself', () {
      final hints = buildCompletionHints(
        rules: rules,
        recentWords: words,
        input: 'trunk',
      );
      expect(labels(hints), isEmpty);
    });

    test('short prefixes are ignored to keep the bar quiet', () {
      expect(
        buildCompletionHints(
          rules: rules,
          recentWords: words,
          input: 'kill g',
        ),
        isEmpty,
      );
    });

    test('a trailing space means no word is being typed', () {
      expect(
        buildCompletionHints(
          rules: rules,
          recentWords: words,
          input: 'kill ',
        ),
        isEmpty,
      );
    });

    test('word hints are capped', () {
      final many = List.generate(20, (i) => 'goblin$i');
      final hints = buildCompletionHints(
        rules: rules,
        recentWords: many,
        input: 'gob',
        maxWordHints: 4,
      );
      expect(hints, hasLength(4));
    });

    test('a rule and a word producing the same line are not duplicated', () {
      final hints = buildCompletionHints(
        rules: rules,
        recentWords: words,
        input: 'po',
      );
      // The rule offers `powerup`; the word list would too — one hint only.
      expect(labels(hints), ['powerup']);
    });
  });
}
