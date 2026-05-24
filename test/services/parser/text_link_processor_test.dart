import 'package:ancient_anguish_client/models/text_link_rule.dart';
import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/services/parser/text_link_processor.dart';
import 'package:flutter_test/flutter_test.dart';

StyledLine _line(String text) => StyledLine([StyledSpan(text: text)]);

void main() {
  group('TextLinkProcessor', () {
    test('returns original line when no rules match', () {
      final processor = TextLinkProcessor([
        const TextLinkRule(
          id: '1',
          name: 'stand',
          pattern: r'You must be standing\.',
          commandTemplate: 'stand',
        ),
      ]);
      final original = _line('Nothing to see here.');
      final result = processor.processLine(original);
      expect(identical(result, original), isTrue);
    });

    test('promotes a full-line match to a command span', () {
      final processor = TextLinkProcessor([
        const TextLinkRule(
          id: '1',
          name: 'stand',
          pattern: r'You must be standing\.',
          commandTemplate: 'stand',
        ),
      ]);
      final out = processor.processLine(_line('You must be standing.'));
      expect(out.spans.length, 1);
      expect(out.spans.first.command, 'stand');
      expect(out.spans.first.text, 'You must be standing.');
    });

    test('splices around a partial match preserving surrounding text', () {
      final processor = TextLinkProcessor([
        const TextLinkRule(
          id: '1',
          name: 'open door',
          pattern: r'The (\w+) door is closed\.',
          commandTemplate: r'open $1 door',
        ),
      ]);
      final out = processor.processLine(
          _line('Prefix. The dark door is closed. Suffix.'));
      // 3 spans expected: prefix, the link, suffix.
      expect(out.spans.length, 3);
      expect(out.spans[0].command, isNull);
      expect(out.spans[0].text, 'Prefix. ');
      expect(out.spans[1].command, 'open dark door');
      expect(out.spans[1].text, 'The dark door is closed.');
      expect(out.spans[2].command, isNull);
      expect(out.spans[2].text, ' Suffix.');
    });

    test('handles multiple non-overlapping matches in one line', () {
      final processor = TextLinkProcessor([
        const TextLinkRule(
          id: 'open',
          name: 'open',
          pattern: r'The (\w+) door is closed\.',
          commandTemplate: r'open $1 door',
        ),
      ]);
      final out = processor.processLine(_line(
          'The north door is closed. The south door is closed.'));
      // Expect: matching span, separator, matching span.
      expect(out.spans.length, 3);
      expect(out.spans[0].command, 'open north door');
      expect(out.spans[1].command, isNull);
      expect(out.spans[1].text, ' ');
      expect(out.spans[2].command, 'open south door');
    });

    test('drops invalid-regex rules silently', () {
      final processor = TextLinkProcessor([
        const TextLinkRule(
          id: 'bad',
          name: 'bad',
          pattern: '(', // unbalanced
          commandTemplate: 'noop',
        ),
        const TextLinkRule(
          id: 'good',
          name: 'good',
          pattern: r'You must be standing\.',
          commandTemplate: 'stand',
        ),
      ]);
      final out = processor.processLine(_line('You must be standing.'));
      expect(out.spans.first.command, 'stand');
    });

    test('skips disabled rules', () {
      final processor = TextLinkProcessor([
        const TextLinkRule(
          id: 'off',
          name: 'off',
          pattern: r'You must be standing\.',
          commandTemplate: 'stand',
          enabled: false,
        ),
      ]);
      final original = _line('You must be standing.');
      final result = processor.processLine(original);
      expect(identical(result, original), isTrue);
    });

    test('isEmpty when all rules disabled or invalid', () {
      final processor = TextLinkProcessor([
        const TextLinkRule(
          id: 'off',
          name: 'off',
          pattern: 'abc',
          commandTemplate: 'noop',
          enabled: false,
        ),
        const TextLinkRule(
          id: 'bad',
          name: 'bad',
          pattern: '(',
          commandTemplate: 'noop',
        ),
      ]);
      expect(processor.isEmpty, isTrue);
    });
  });

  group('TextLinkRule.resolveCommand', () {
    test('substitutes capture groups via \$N', () {
      const rule = TextLinkRule(
        id: 'r',
        name: 'r',
        pattern: r'(\w+) door',
        commandTemplate: r'open $1 door',
      );
      final m = RegExp(rule.pattern).firstMatch('the heavy door now')!;
      expect(rule.resolveCommand(m), 'open heavy door');
    });

    test('substitutes whole match via \$0', () {
      const rule = TextLinkRule(
        id: 'r',
        name: 'r',
        pattern: r'\w+ door',
        commandTemplate: r'open $0',
      );
      final m = RegExp(rule.pattern).firstMatch('the dark door')!;
      expect(rule.resolveCommand(m), 'open dark door');
    });

    test('missing groups become empty strings', () {
      const rule = TextLinkRule(
        id: 'r',
        name: 'r',
        pattern: 'foo',
        commandTemplate: r'do $1 $2',
      );
      final m = RegExp(rule.pattern).firstMatch('foo')!;
      expect(rule.resolveCommand(m), 'do');
    });
  });
}
