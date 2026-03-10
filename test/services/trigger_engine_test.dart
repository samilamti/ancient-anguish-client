import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/trigger_rule.dart';
import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/services/trigger/trigger_engine.dart';

void main() {
  late TriggerEngine engine;

  setUp(() {
    engine = TriggerEngine();
  });

  StyledLine makeLine(String text) {
    return StyledLine([StyledSpan(text: text)]);
  }

  group('TriggerEngine - Rule management', () {
    test('starts with no rules', () {
      expect(engine.rules, isEmpty);
    });

    test('addRule adds a rule', () {
      engine.addRule(TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: 'hello',
      ));
      expect(engine.rules, hasLength(1));
      expect(engine.rules.first.name, 'Test');
    });

    test('removeRule removes by ID', () {
      engine.addRule(TriggerRule(id: 't1', name: 'A', pattern: 'a'));
      engine.addRule(TriggerRule(id: 't2', name: 'B', pattern: 'b'));
      engine.removeRule('t1');
      expect(engine.rules, hasLength(1));
      expect(engine.rules.first.id, 't2');
    });

    test('updateRule replaces existing rule', () {
      engine.addRule(TriggerRule(id: 't1', name: 'Old', pattern: 'old'));
      engine.updateRule(TriggerRule(id: 't1', name: 'New', pattern: 'new'));
      expect(engine.rules.first.name, 'New');
      expect(engine.rules.first.pattern, 'new');
    });

    test('getRule returns rule by ID', () {
      engine.addRule(TriggerRule(id: 't1', name: 'A', pattern: 'a'));
      expect(engine.getRule('t1')?.name, 'A');
      expect(engine.getRule('nonexistent'), isNull);
    });

    test('setRules replaces all rules', () {
      engine.addRule(TriggerRule(id: 't1', name: 'Old', pattern: 'old'));
      engine.setRules([
        TriggerRule(id: 't2', name: 'New1', pattern: 'new1'),
        TriggerRule(id: 't3', name: 'New2', pattern: 'new2'),
      ]);
      expect(engine.rules, hasLength(2));
      expect(engine.rules.first.id, 't2');
    });
  });

  group('TriggerEngine - Highlight processing', () {
    test('line with no matching triggers passes through unchanged', () {
      engine.addRule(TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: 'hello',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFF0000),
      ));

      final line = makeLine('goodbye world');
      final result = engine.processLine(line);
      expect(result.firedTriggers, isEmpty);
      expect(result.gagged, false);
      expect(result.styledLine.plainText, 'goodbye world');
    });

    test('matching trigger highlights text', () {
      engine.addRule(TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: 'hello',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFF0000),
      ));

      final line = makeLine('say hello world');
      final result = engine.processLine(line);
      expect(result.firedTriggers, hasLength(1));
      expect(result.firedTriggers.first.id, 't1');
      // The highlighted line should still have the same plain text.
      expect(result.styledLine.plainText, 'say hello world');
      // But should have more spans (split at highlight boundaries).
      expect(result.styledLine.spans.length, greaterThan(1));
    });

    test('whole-line highlight applies to all spans', () {
      engine.addRule(TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: 'tells you',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFF00FF00),
        highlightWholeLine: true,
      ));

      final line = makeLine('Gandalf tells you: Hello!');
      final result = engine.processLine(line);
      expect(result.firedTriggers, hasLength(1));
      // All spans should have the highlight color.
      for (final span in result.styledLine.spans) {
        expect(span.foreground, const Color(0xFF00FF00));
      }
    });

    test('disabled trigger does not match', () {
      engine.addRule(TriggerRule(
        id: 't1',
        name: 'Test',
        pattern: 'hello',
        enabled: false,
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFF0000),
      ));

      final line = makeLine('hello world');
      final result = engine.processLine(line);
      expect(result.firedTriggers, isEmpty);
    });
  });

  group('TriggerEngine - Gag', () {
    test('gag trigger marks line for suppression', () {
      engine.addRule(TriggerRule(
        id: 't1',
        name: 'Gag spam',
        pattern: r'^\[OOC\]',
        action: TriggerAction.gag,
      ));

      final result = engine.processLine(makeLine('[OOC] Spam message'));
      expect(result.gagged, true);
    });

    test('non-matching gag does not suppress', () {
      engine.addRule(TriggerRule(
        id: 't1',
        name: 'Gag spam',
        pattern: r'^\[OOC\]',
        action: TriggerAction.gag,
      ));

      final result = engine.processLine(makeLine('Normal message'));
      expect(result.gagged, false);
    });
  });

  group('TriggerEngine - Sound triggers', () {
    test('sound trigger fires callback', () {
      String? firedText;
      TriggerRule? firedRule;

      engine.onTriggerFired = (rule, text) {
        firedRule = rule;
        firedText = text;
      };

      engine.addRule(TriggerRule(
        id: 't1',
        name: 'Alert',
        pattern: 'tells you',
        action: TriggerAction.playSound,
        soundPath: '/path/to/alert.mp3',
      ));

      engine.processLine(makeLine('Gandalf tells you: Hi'));
      expect(firedRule?.id, 't1');
      expect(firedText, contains('tells you'));
    });

    test('highlightAndSound fires callback AND highlights', () {
      var callbackFired = false;
      engine.onTriggerFired = (_, _) => callbackFired = true;

      engine.addRule(TriggerRule(
        id: 't1',
        name: 'Both',
        pattern: 'danger',
        action: TriggerAction.highlightAndSound,
        highlightForeground: const Color(0xFFFF0000),
        highlightWholeLine: true,
      ));

      final result = engine.processLine(makeLine('Warning: danger ahead!'));
      expect(callbackFired, true);
      expect(result.firedTriggers, hasLength(1));
      for (final span in result.styledLine.spans) {
        expect(span.foreground, const Color(0xFFFF0000));
      }
    });
  });

  group('TriggerEngine - Multiple triggers', () {
    test('multiple triggers can match the same line', () {
      engine.addRule(TriggerRule(
        id: 't1',
        name: 'Color1',
        pattern: 'hello',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFF0000),
      ));
      engine.addRule(TriggerRule(
        id: 't2',
        name: 'Sound1',
        pattern: 'world',
        action: TriggerAction.playSound,
      ));

      final result = engine.processLine(makeLine('hello world'));
      expect(result.firedTriggers, hasLength(2));
    });
  });

  group('TriggerRule - Model', () {
    test('matches returns true for matching pattern', () {
      final rule = TriggerRule(id: 't1', name: 'T', pattern: r'\w+ tells you:');
      expect(rule.matches('Gandalf tells you: Hello'), true);
      expect(rule.matches('Some random line'), false);
    });

    test('matches is case-insensitive', () {
      final rule = TriggerRule(id: 't1', name: 'T', pattern: 'hello');
      expect(rule.matches('HELLO WORLD'), true);
    });

    test('invalid regex returns no matches', () {
      final rule = TriggerRule(id: 't1', name: 'T', pattern: r'[invalid');
      expect(rule.matches('anything'), false);
      expect(rule.findMatches('anything'), isEmpty);
    });

    test('findMatches returns all match positions', () {
      final rule = TriggerRule(id: 't1', name: 'T', pattern: r'\d+');
      final matches = rule.findMatches('foo 123 bar 456');
      expect(matches, hasLength(2));
      expect(matches[0].matchedText, '123');
      expect(matches[1].matchedText, '456');
    });

    test('JSON round-trip preserves all fields', () {
      final original = TriggerRule(
        id: 'test_id',
        name: 'Test Trigger',
        pattern: r'hello (\w+)',
        enabled: false,
        action: TriggerAction.highlightAndSound,
        highlightForeground: const Color(0xFFFF0000),
        highlightBackground: const Color(0xFF001100),
        highlightBold: true,
        soundPath: '/path/to/sound.mp3',
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

    test('copyWith creates modified copy', () {
      final original = TriggerRule(id: 't1', name: 'A', pattern: 'a');
      final copy = original.copyWith(name: 'B', enabled: false);
      expect(copy.id, 't1');
      expect(copy.name, 'B');
      expect(copy.pattern, 'a');
      expect(copy.enabled, false);
    });
  });
}
