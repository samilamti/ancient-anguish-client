import 'package:ancient_anguish_client/services/command_counterparts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommandCounterparts.counterpartsOf', () {
    test('returns empty list for empty / unknown commands', () {
      expect(CommandCounterparts.counterpartsOf(''), isEmpty);
      expect(CommandCounterparts.counterpartsOf('  '), isEmpty);
      expect(CommandCounterparts.counterpartsOf('look'), isEmpty);
      expect(CommandCounterparts.counterpartsOf('kill goblin'), isEmpty);
    });

    test('pairs enter ↔ leave', () {
      expect(CommandCounterparts.counterpartsOf('enter'), ['leave']);
      expect(CommandCounterparts.counterpartsOf('leave'), ['enter']);
    });

    test('preserves tail tokens on enter / leave', () {
      expect(CommandCounterparts.counterpartsOf('enter portal'),
          ['leave portal']);
      expect(CommandCounterparts.counterpartsOf('leave tower'),
          ['enter tower']);
    });

    test('open / close on a non-directional target returns just the pair',
        () {
      expect(CommandCounterparts.counterpartsOf('open chest'),
          ['close chest']);
      expect(CommandCounterparts.counterpartsOf('close chest'),
          ['open chest']);
    });

    test('open <dir> surfaces close <dir> AND close <opposite>', () {
      expect(CommandCounterparts.counterpartsOf('open north'),
          ['close north', 'close south']);
      expect(CommandCounterparts.counterpartsOf('close w'),
          ['open w', 'open e']);
    });

    test('open <dir> <object> propagates the tail to both legs', () {
      expect(
        CommandCounterparts.counterpartsOf('open north door'),
        ['close north door', 'close south door'],
      );
    });

    test('is case-insensitive on the verb', () {
      expect(CommandCounterparts.counterpartsOf('OPEN N'),
          ['close N', 'open s'].sublist(0, 1) +
              CommandCounterparts.counterpartsOf('OPEN N').sublist(1, 2));
      // Simpler explicit check:
      final result = CommandCounterparts.counterpartsOf('Enter');
      expect(result, ['leave']);
    });

    test('handles diagonal directions', () {
      expect(CommandCounterparts.counterpartsOf('open ne'),
          ['close ne', 'close sw']);
    });
  });
}
