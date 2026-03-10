import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/alias_rule.dart';
import 'package:ancient_anguish_client/providers/alias_provider.dart';

void main() {
  late ProviderContainer container;
  late AliasRulesNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(aliasRulesProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('AliasRulesNotifier', () {
    test('build loads default aliases', () {
      final rules = container.read(aliasRulesProvider);
      expect(rules, isNotEmpty);
    });

    test('addRule adds to state', () {
      final initialCount = container.read(aliasRulesProvider).length;
      notifier.addRule(const AliasRule(
        id: 'custom1',
        keyword: 'zz',
        expansion: 'zzap all',
      ));
      expect(container.read(aliasRulesProvider), hasLength(initialCount + 1));
    });

    test('removeRule removes from state', () {
      final rules = container.read(aliasRulesProvider);
      final firstId = rules.first.id;
      final initialCount = rules.length;

      notifier.removeRule(firstId);
      expect(container.read(aliasRulesProvider), hasLength(initialCount - 1));
    });

    test('updateRule modifies existing rule', () {
      final rules = container.read(aliasRulesProvider);
      final first = rules.first;

      notifier.updateRule(first.copyWith(expansion: 'new expansion'));

      final updated = container
          .read(aliasRulesProvider)
          .firstWhere((r) => r.id == first.id);
      expect(updated.expansion, 'new expansion');
    });

    test('toggleRule flips enabled state', () {
      final rules = container.read(aliasRulesProvider);
      final first = rules.first;
      expect(first.enabled, isTrue);

      notifier.toggleRule(first.id);

      final toggled = container
          .read(aliasRulesProvider)
          .firstWhere((r) => r.id == first.id);
      expect(toggled.enabled, isFalse);
    });

    test('setRules replaces all rules', () {
      const newRules = [
        AliasRule(id: 'new1', keyword: 'xx', expansion: 'test'),
      ];
      notifier.setRules(newRules);
      final rules = container.read(aliasRulesProvider);
      expect(rules, hasLength(1));
      expect(rules.first.id, 'new1');
    });

    test('state is unmodifiable list', () {
      final rules = container.read(aliasRulesProvider);
      expect(
        () => (rules as List<AliasRule>).add(
          const AliasRule(id: 'x', keyword: 'x', expansion: 'x'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
