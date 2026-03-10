import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/trigger_rule.dart';

void main() {
  group('TriggerRule - compiledPattern', () {
    test('compiles a valid regex', () {
      final rule = TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: r'\w+ tells you:',
      );
      expect(rule.compiledPattern, isNotNull);
      expect(rule.compiledPattern, isA<RegExp>());
    });

    test('returns same instance on subsequent calls (cached)', () {
      final rule = TriggerRule(id: 't1', name: 'Test', pattern: r'hello');
      final first = rule.compiledPattern;
      final second = rule.compiledPattern;
      expect(identical(first, second), isTrue);
    });

    test('returns null for invalid regex pattern', () {
      final rule = TriggerRule(id: 't1', name: 'Test', pattern: r'[invalid');
      expect(rule.compiledPattern, isNull);
    });
  });

  group('TriggerRule - matches', () {
    test('returns true for matching text', () {
      final rule = TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: r'tells you:',
      );
      expect(rule.matches('Gandalf tells you: hello'), isTrue);
    });

    test('returns false for non-matching text', () {
      final rule = TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: r'tells you:',
      );
      expect(rule.matches('You say: hello'), isFalse);
    });

    test('returns false when disabled', () {
      final rule = TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: r'tells you:',
        enabled: false,
      );
      expect(rule.matches('Gandalf tells you: hello'), isFalse);
    });

    test('is case-insensitive', () {
      final rule = TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: r'HELLO',
      );
      expect(rule.matches('hello world'), isTrue);
    });

    test('returns false when pattern is invalid', () {
      final rule = TriggerRule(id: 't1', name: 'Test', pattern: r'[bad');
      expect(rule.matches('anything'), isFalse);
    });
  });

  group('TriggerRule - findMatches', () {
    test('returns empty when disabled', () {
      final rule = TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: r'hello',
        enabled: false,
      );
      expect(rule.findMatches('hello hello'), isEmpty);
    });

    test('returns correct start/end positions', () {
      final rule = TriggerRule(id: 't1', name: 'Test', pattern: r'world');
      final matches = rule.findMatches('hello world!');
      expect(matches, hasLength(1));
      expect(matches[0].start, 6);
      expect(matches[0].end, 11);
      expect(matches[0].matchedText, 'world');
    });

    test('finds multiple matches', () {
      final rule = TriggerRule(id: 't1', name: 'Test', pattern: r'ab');
      final matches = rule.findMatches('ab cd ab ef ab');
      expect(matches, hasLength(3));
    });

    test('returns empty for non-matching text', () {
      final rule = TriggerRule(id: 't1', name: 'Test', pattern: r'xyz');
      expect(rule.findMatches('hello world'), isEmpty);
    });

    test('returns empty when pattern is invalid', () {
      final rule = TriggerRule(id: 't1', name: 'Test', pattern: r'[bad');
      expect(rule.findMatches('anything'), isEmpty);
    });
  });

  group('TriggerRule - copyWith', () {
    test('preserves unspecified fields', () {
      final rule = TriggerRule(
        id: 't1',
        name: 'Original',
        pattern: r'test',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFF00FF00),
        highlightBold: true,
        highlightWholeLine: true,
      );

      final copied = rule.copyWith(name: 'Updated');
      expect(copied.id, 't1');
      expect(copied.name, 'Updated');
      expect(copied.pattern, r'test');
      expect(copied.action, TriggerAction.highlight);
      expect(copied.highlightForeground, const Color(0xFF00FF00));
      expect(copied.highlightBold, isTrue);
      expect(copied.highlightWholeLine, isTrue);
    });

    test('toggles enabled state', () {
      final rule = TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: r'test',
        enabled: true,
      );
      final disabled = rule.copyWith(enabled: false);
      expect(disabled.enabled, isFalse);
    });
  });

  group('TriggerRule - JSON round-trip', () {
    test('preserves all fields including colors', () {
      final original = TriggerRule(
        id: 't1',
        name: 'Combat',
        pattern: r'attacks you',
        enabled: true,
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFF0000),
        highlightBackground: const Color(0xFF330000),
        highlightBold: true,
        soundPath: 'sounds/alert.mp3',
        highlightWholeLine: true,
      );

      final json = original.toJson();
      final restored = TriggerRule.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.pattern, original.pattern);
      expect(restored.enabled, original.enabled);
      expect(restored.action, original.action);
      expect(restored.highlightForeground, original.highlightForeground);
      expect(restored.highlightBackground, original.highlightBackground);
      expect(restored.highlightBold, original.highlightBold);
      expect(restored.soundPath, original.soundPath);
      expect(restored.highlightWholeLine, original.highlightWholeLine);
    });

    test('uses defaults for missing optional fields', () {
      final json = {
        'id': 't1',
        'name': 'Minimal',
        'pattern': r'test',
      };
      final rule = TriggerRule.fromJson(json);
      expect(rule.enabled, isTrue);
      expect(rule.action, TriggerAction.highlight);
      expect(rule.highlightForeground, isNull);
      expect(rule.highlightBackground, isNull);
      expect(rule.highlightBold, isFalse);
      expect(rule.soundPath, isNull);
      expect(rule.highlightWholeLine, isFalse);
    });

    test('serializes all TriggerAction values correctly', () {
      for (final action in TriggerAction.values) {
        final rule = TriggerRule(
          id: 'test',
          name: 'Test',
          pattern: 'test',
          action: action,
        );
        final json = rule.toJson();
        final restored = TriggerRule.fromJson(json);
        expect(restored.action, action);
      }
    });
  });

  group('TriggerRule - toString', () {
    test('includes name, pattern, and action', () {
      final rule = TriggerRule(
        id: 't1',
        name: 'Combat',
        pattern: r'attacks you',
        action: TriggerAction.highlight,
      );
      expect(
        rule.toString(),
        'TriggerRule(Combat, /attacks you/, TriggerAction.highlight)',
      );
    });
  });
}
