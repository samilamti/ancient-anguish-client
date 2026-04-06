import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/trigger_rule.dart';
import 'package:ancient_anguish_client/providers/trigger_provider.dart';

void main() {
  late ProviderContainer container;
  late TriggerRulesNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(triggerRulesProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('TriggerRulesNotifier', () {
    test('build loads default trigger rules', () {
      final rules = container.read(triggerRulesProvider);
      expect(rules, isNotEmpty);
      // Default rules include 'Tells', 'Shouts', 'Being attacked', 'Low HP'.
      expect(rules, hasLength(4));
      expect(rules.any((r) => r.name == 'Tells (messages)'), isTrue);
      expect(rules.any((r) => r.name == 'Shouts'), isTrue);
      expect(rules.any((r) => r.name == 'Being attacked'), isTrue);
      expect(rules.any((r) => r.name == 'Low HP warning'), isTrue);
    });

    test('addRule adds to state', () {
      final initialCount = container.read(triggerRulesProvider).length;
      notifier.addRule(TriggerRule(
        id: 'custom1',
        name: 'Custom',
        pattern: r'test pattern',
      ));
      expect(container.read(triggerRulesProvider), hasLength(initialCount + 1));
    });

    test('removeRule removes from state', () {
      final initialCount = container.read(triggerRulesProvider).length;
      notifier.removeRule('hl_01');
      expect(container.read(triggerRulesProvider), hasLength(initialCount - 1));
      expect(
        container.read(triggerRulesProvider).any((r) => r.id == 'hl_01'),
        isFalse,
      );
    });

    test('updateRule modifies existing rule', () {
      final original = container
          .read(triggerRulesProvider)
          .firstWhere((r) => r.id == 'hl_01');
      notifier.updateRule(original.copyWith(
        name: 'Updated Tells',
        highlightForeground: const Color(0xFFFF0000),
      ));
      final updated = container
          .read(triggerRulesProvider)
          .firstWhere((r) => r.id == 'hl_01');
      expect(updated.name, 'Updated Tells');
      expect(updated.highlightForeground, const Color(0xFFFF0000));
    });

    test('toggleRule flips enabled state', () {
      final before = container
          .read(triggerRulesProvider)
          .firstWhere((r) => r.id == 'hl_01');
      expect(before.enabled, isTrue);

      notifier.toggleRule('hl_01');

      final after = container
          .read(triggerRulesProvider)
          .firstWhere((r) => r.id == 'hl_01');
      expect(after.enabled, isFalse);
    });

    test('toggleRule with nonexistent ID does nothing', () {
      final before = container.read(triggerRulesProvider).length;
      notifier.toggleRule('nonexistent_id');
      expect(container.read(triggerRulesProvider), hasLength(before));
    });

    test('setRules replaces all', () {
      final newRules = [
        TriggerRule(id: 'new1', name: 'New Rule', pattern: r'new'),
      ];
      notifier.setRules(newRules);
      final rules = container.read(triggerRulesProvider);
      expect(rules, hasLength(1));
      expect(rules.first.id, 'new1');
    });

    test('state is unmodifiable list', () {
      final rules = container.read(triggerRulesProvider);
      expect(
        () => rules.add(
          TriggerRule(id: 'x', name: 'x', pattern: 'x'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
