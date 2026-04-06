import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/alias_rule.dart';

void main() {
  group('AliasRule - tryExpand', () {
    test('expands exact keyword match', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack all',
      );
      expect(rule.tryExpand('aa'), 'attack all');
    });

    test('expands keyword with arguments using \$0', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'say',
        expansion: 'say to all \$0',
      );
      expect(rule.tryExpand('say hello world'), 'say to all hello world');
    });

    test('expands keyword with positional args \$1, \$2', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack \$1 with \$2',
      );
      expect(rule.tryExpand('aa goblin axe'), 'attack goblin with axe');
    });

    test('cleans up unresolved variable references', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack \$1 with \$2',
      );
      // Only one argument provided, $2 should be cleaned up.
      expect(rule.tryExpand('aa goblin'), 'attack goblin with');
    });

    test('rejects prefix of longer word', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack all',
      );
      expect(rule.tryExpand('aardvark'), isNull);
    });

    test('returns null when disabled', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack all',
        enabled: false,
      );
      expect(rule.tryExpand('aa'), isNull);
    });

    test('returns null for non-matching input', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack all',
      );
      expect(rule.tryExpand('bb'), isNull);
    });

    test('handles empty args string', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'look',
        expansion: 'look around \$0',
      );
      // $0 is empty, gets replaced with empty string.
      expect(rule.tryExpand('look'), 'look around');
    });

    test('trims leading/trailing whitespace from input', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack all',
      );
      expect(rule.tryExpand('  aa  '), 'attack all');
    });

    test('handles up to 9 positional arguments', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'test',
        expansion: '\$1-\$2-\$3-\$4-\$5-\$6-\$7-\$8-\$9',
      );
      expect(
        rule.tryExpand('test a b c d e f g h i'),
        'a-b-c-d-e-f-g-h-i',
      );
    });
  });

  group('AliasRule - copyWith', () {
    test('preserves unspecified fields', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack all',
        description: 'Attack everything',
      );
      final copied = rule.copyWith(keyword: 'bb');
      expect(copied.id, 'a1');
      expect(copied.keyword, 'bb');
      expect(copied.expansion, 'attack all');
      expect(copied.description, 'Attack everything');
      expect(copied.enabled, isTrue);
    });

    test('toggles enabled state', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack all',
      );
      final disabled = rule.copyWith(enabled: false);
      expect(disabled.enabled, isFalse);
    });
  });

  group('AliasRule - JSON round-trip', () {
    test('preserves all fields', () {
      const original = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack \$1 with axe',
        enabled: true,
        description: 'Quick attack',
      );

      final json = original.toJson();
      final restored = AliasRule.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.keyword, original.keyword);
      expect(restored.expansion, original.expansion);
      expect(restored.enabled, original.enabled);
      expect(restored.description, original.description);
    });

    test('handles null description', () {
      const original = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack all',
      );
      final json = original.toJson();
      final restored = AliasRule.fromJson(json);
      expect(restored.description, isNull);
    });

    test('defaults enabled to true when missing from JSON', () {
      final json = {
        'id': 'a1',
        'keyword': 'aa',
        'expansion': 'attack all',
      };
      final rule = AliasRule.fromJson(json);
      expect(rule.enabled, isTrue);
    });
  });

  group('AliasRule - toString', () {
    test('includes keyword and expansion', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'aa',
        expansion: 'attack all',
      );
      expect(rule.toString(), 'AliasRule(aa → attack all)');
    });
  });
}
