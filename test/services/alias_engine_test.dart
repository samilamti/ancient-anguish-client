import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/alias_rule.dart';
import 'package:ancient_anguish_client/services/alias/alias_engine.dart';

void main() {
  late AliasEngine engine;

  setUp(() {
    engine = AliasEngine();
  });

  group('AliasEngine - Rule management', () {
    test('starts with no rules', () {
      expect(engine.rules, isEmpty);
    });

    test('addRule adds a rule', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'k', expansion: 'kill \$1'));
      expect(engine.rules, hasLength(1));
    });

    test('removeRule removes by ID', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'k', expansion: 'kill \$1'));
      engine.addRule(const AliasRule(id: 'a2', keyword: 'ga', expansion: 'get all'));
      engine.removeRule('a1');
      expect(engine.rules, hasLength(1));
      expect(engine.rules.first.id, 'a2');
    });

    test('updateRule replaces existing rule', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'k', expansion: 'kill \$1'));
      engine.updateRule(const AliasRule(id: 'a1', keyword: 'k', expansion: 'kick \$1'));
      expect(engine.rules.first.expansion, 'kick \$1');
    });

    test('setRules replaces all rules', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'old', expansion: 'old'));
      engine.setRules([
        const AliasRule(id: 'a2', keyword: 'new1', expansion: 'new1'),
        const AliasRule(id: 'a3', keyword: 'new2', expansion: 'new2'),
      ]);
      expect(engine.rules, hasLength(2));
    });

    test('defaultAliases returns standard AA aliases', () {
      final defaults = AliasEngine.defaultAliases();
      expect(defaults, isNotEmpty);
      expect(defaults.any((a) => a.keyword == 'ga'), true);
      expect(defaults.any((a) => a.keyword == 'k'), true);
    });
  });

  group('AliasEngine - Expansion', () {
    test('expands simple alias', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'ga', expansion: 'get all'));
      final result = engine.expand('ga');
      expect(result, ['get all']);
    });

    test('expands alias with \$1 substitution', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'k', expansion: 'kill \$1'));
      final result = engine.expand('k goblin');
      expect(result, ['kill goblin']);
    });

    test('expands alias with \$0 substitution', () {
      engine.addRule(const AliasRule(
        id: 'a1',
        keyword: 'c',
        expansion: 'cast \$0',
      ));
      final result = engine.expand('c fireball at goblin');
      expect(result, ['cast fireball at goblin']);
    });

    test('expands alias with multiple args', () {
      engine.addRule(const AliasRule(
        id: 'a1',
        keyword: 'give',
        expansion: 'give \$1 to \$2',
      ));
      final result = engine.expand('give sword warrior');
      expect(result, ['give sword to warrior']);
    });

    test('returns original command when no alias matches', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'ga', expansion: 'get all'));
      final result = engine.expand('look');
      expect(result, ['look']);
    });

    test('does not match prefix of longer word', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'k', expansion: 'kill \$1'));
      final result = engine.expand('kick goblin');
      expect(result, ['kick goblin']);
    });

    test('disabled alias is not expanded', () {
      engine.addRule(const AliasRule(
        id: 'a1',
        keyword: 'ga',
        expansion: 'get all',
        enabled: false,
      ));
      final result = engine.expand('ga');
      expect(result, ['ga']);
    });

    test('cleans up unresolved variables', () {
      engine.addRule(const AliasRule(
        id: 'a1',
        keyword: 'k',
        expansion: 'kill \$1 with \$2',
      ));
      // Only provide one arg.
      final result = engine.expand('k goblin');
      expect(result, ['kill goblin with']);
    });

    test('handles empty input', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'ga', expansion: 'get all'));
      final result = engine.expand('');
      expect(result, ['']);
    });
  });

  group('AliasEngine - Semicolon commands', () {
    test('splits semicolon-separated commands', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'ga', expansion: 'get all'));
      final result = engine.expand('ga; look');
      expect(result, ['get all', 'look']);
    });

    test('expands aliases in each semicolon segment', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'ga', expansion: 'get all'));
      engine.addRule(const AliasRule(id: 'a2', keyword: 'sc', expansion: 'score'));
      final result = engine.expand('ga; sc');
      expect(result, ['get all', 'score']);
    });
  });

  group('AliasEngine - Loop prevention', () {
    test('prevents infinite recursion', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'a', expansion: 'b'));
      engine.addRule(const AliasRule(id: 'a2', keyword: 'b', expansion: 'a'));
      // Should not hang — max depth prevents infinite loop.
      final result = engine.expand('a');
      expect(result, isNotEmpty);
    });
  });

  group('AliasEngine - hasMatch', () {
    test('returns true when alias matches', () {
      engine.addRule(const AliasRule(id: 'a1', keyword: 'ga', expansion: 'get all'));
      expect(engine.hasMatch('ga'), true);
      expect(engine.hasMatch('look'), false);
    });
  });

  group('AliasRule - Model', () {
    test('tryExpand returns expanded command on match', () {
      const rule = AliasRule(id: 'a1', keyword: 'k', expansion: r'kill $1');
      expect(rule.tryExpand('k goblin'), 'kill goblin');
    });

    test('tryExpand returns null on no match', () {
      const rule = AliasRule(id: 'a1', keyword: 'k', expansion: r'kill $1');
      expect(rule.tryExpand('look'), isNull);
    });

    test('tryExpand returns null when disabled', () {
      const rule = AliasRule(
        id: 'a1',
        keyword: 'k',
        expansion: r'kill $1',
        enabled: false,
      );
      expect(rule.tryExpand('k goblin'), isNull);
    });

    test('JSON round-trip preserves all fields', () {
      const original = AliasRule(
        id: 'test_id',
        keyword: 'testcmd',
        expansion: r'full command $1',
        enabled: false,
        description: 'Test description',
      );

      final json = original.toJson();
      final restored = AliasRule.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.keyword, original.keyword);
      expect(restored.expansion, original.expansion);
      expect(restored.enabled, original.enabled);
      expect(restored.description, original.description);
    });

    test('copyWith creates modified copy', () {
      const original = AliasRule(id: 'a1', keyword: 'k', expansion: r'kill $1');
      final copy = original.copyWith(keyword: 'kk', enabled: false);
      expect(copy.id, 'a1');
      expect(copy.keyword, 'kk');
      expect(copy.expansion, r'kill $1');
      expect(copy.enabled, false);
    });
  });
}
