import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/command_loops.dart';

void main() {
  group('CommandLoops.breakCommandFor', () {
    test('maps a bare dotimes to breakdo', () {
      expect(CommandLoops.breakCommandFor('dotimes'), 'breakdo');
    });

    test('maps dotimes with arguments to breakdo', () {
      expect(CommandLoops.breakCommandFor('dotimes 30 kill orc'), 'breakdo');
    });

    test('is case-insensitive and tolerates surrounding whitespace', () {
      expect(CommandLoops.breakCommandFor('  DoTimes 5 north '), 'breakdo');
    });

    test('does not match a different command that merely starts with dotimes',
        () {
      expect(CommandLoops.breakCommandFor('dotimesfoo'), isNull);
    });

    test('returns null for unrelated or empty commands', () {
      expect(CommandLoops.breakCommandFor('kill orc'), isNull);
      expect(CommandLoops.breakCommandFor(''), isNull);
      expect(CommandLoops.breakCommandFor('breakdo'), isNull);
    });
  });
}
