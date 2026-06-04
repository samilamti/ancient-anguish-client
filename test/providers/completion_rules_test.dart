import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/completion_rules_provider.dart';

void main() {
  group('matchCompletions', () {
    test('returns the completion for an exact trigger', () {
      final m = matchCompletions(kDefaultCompletionRules, 'dot');
      expect(m, hasLength(1));
      expect(m.first.completion, 'dotimes 30 ');
    });

    test('preserves the trailing space in the completion', () {
      final m = matchCompletions(kDefaultCompletionRules, 'dot');
      expect(m.first.completion.endsWith(' '), isTrue);
    });

    test('matches each seeded rule', () {
      expect(
        matchCompletions(kDefaultCompletionRules, 'po').first.completion,
        'powerup',
      );
      expect(
        matchCompletions(kDefaultCompletionRules, 'i t').first.completion,
        'i trunk -c',
      );
    });

    test('is case-insensitive and trims surrounding whitespace', () {
      expect(
        matchCompletions(kDefaultCompletionRules, '  DOT ').first.completion,
        'dotimes 30 ',
      );
    });

    test('returns empty for empty or whitespace input', () {
      expect(matchCompletions(kDefaultCompletionRules, ''), isEmpty);
      expect(matchCompletions(kDefaultCompletionRules, '   '), isEmpty);
    });

    test('does not fire on a partial trigger or past it', () {
      // A prefix of the trigger ("do") must not pre-fire.
      expect(matchCompletions(kDefaultCompletionRules, 'do'), isEmpty);
      // Once the user types past the trigger, the suggestion clears.
      expect(matchCompletions(kDefaultCompletionRules, 'dotim'), isEmpty);
    });

    test('returns empty when nothing matches', () {
      expect(matchCompletions(kDefaultCompletionRules, 'xyzzy'), isEmpty);
    });

    test('returns every rule sharing a trigger, in order', () {
      const rules = [
        CompletionRule(trigger: 'g', completion: 'goblin'),
        CompletionRule(trigger: 'g', completion: 'giant'),
      ];
      final m = matchCompletions(rules, 'g');
      expect(m.map((r) => r.completion), ['goblin', 'giant']);
    });
  });
}
