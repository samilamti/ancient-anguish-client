import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/alias/alias_command.dart';

void main() {
  group('AliasCommand.parse', () {
    test('parses keyword and expansion, preserving semicolon chains', () {
      final cmd = AliasCommand.parse('#al bt buy tekillya;drink tekillya');
      expect(cmd, isNotNull);
      expect(cmd!.isValid, isTrue);
      expect(cmd.keyword, 'bt');
      expect(cmd.expansion, 'buy tekillya;drink tekillya');
      expect(cmd.error, isNull);
    });

    test(r'keeps $-variables in the expansion intact', () {
      final cmd = AliasCommand.parse(r'#al k kill $1 with axe');
      expect(cmd!.isValid, isTrue);
      expect(cmd.keyword, 'k');
      expect(cmd.expansion, r'kill $1 with axe');
    });

    test('collapses the gap between keyword and expansion only', () {
      final cmd = AliasCommand.parse('#al   bt    buy   tekillya');
      expect(cmd!.isValid, isTrue);
      expect(cmd.keyword, 'bt');
      // Internal spacing inside the expansion is left as the user typed it.
      expect(cmd.expansion, 'buy   tekillya');
    });

    test('is case-insensitive on the trigger token', () {
      final cmd = AliasCommand.parse('#AL bt buy tekillya');
      expect(cmd, isNotNull);
      expect(cmd!.keyword, 'bt');
      expect(cmd.expansion, 'buy tekillya');
    });

    test('accepts #alias as a second trigger', () {
      final cmd = AliasCommand.parse('#alias bt buy tekillya;drink tekillya');
      expect(cmd, isNotNull);
      expect(cmd!.isValid, isTrue);
      expect(cmd.keyword, 'bt');
      expect(cmd.expansion, 'buy tekillya;drink tekillya');
    });

    test('#alias is case-insensitive and flags its own usage error', () {
      expect(AliasCommand.parse('#ALIAS bt go')!.keyword, 'bt');
      final usage = AliasCommand.parse('#alias');
      expect(usage, isNotNull);
      expect(usage!.isValid, isFalse);
    });

    test('tolerates leading whitespace', () {
      final cmd = AliasCommand.parse('   #al bt buy tekillya  ');
      expect(cmd!.isValid, isTrue);
      expect(cmd.keyword, 'bt');
      expect(cmd.expansion, 'buy tekillya');
    });

    group('returns null (passes through to the MUD) for non-#al input', () {
      for (final input in const [
        'bt buy tekillya',
        'say hello',
        '#also do something', // #al is not a standalone token here
        '#alpha',
        '#alia bt foo', // close, but not #al or #alias
        '',
      ]) {
        test('"$input"', () => expect(AliasCommand.parse(input), isNull));
      }
    });

    test('flags a usage error when only the trigger is given', () {
      final cmd = AliasCommand.parse('#al');
      expect(cmd, isNotNull);
      expect(cmd!.isValid, isFalse);
      expect(cmd.error, isNotNull);
      expect(cmd.keyword, isNull);
      expect(cmd.expansion, isNull);
    });

    test('flags a usage error when the expansion is missing', () {
      final cmd = AliasCommand.parse('#al bt');
      expect(cmd, isNotNull);
      expect(cmd!.isValid, isFalse);
      expect(cmd.error, contains('bt'));
    });
  });
}
