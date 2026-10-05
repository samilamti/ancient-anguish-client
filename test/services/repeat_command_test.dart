import 'package:ancient_anguish_client/services/repeat_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepeatCommand', () {
    test('parses count and body', () {
      final r = RepeatCommand.parse('#15 buy beer;drink beer')!;
      expect(r.count, 15);
      expect(r.body, 'buy beer;drink beer');
    });

    test('repeats the expanded body in order', () {
      final r = RepeatCommand.parse('#3 buy beer;drink beer')!;
      expect(r.repeat(['buy beer', 'drink beer']), [
        'buy beer', 'drink beer',
        'buy beer', 'drink beer',
        'buy beer', 'drink beer',
      ]);
    });

    test('tolerates surrounding whitespace', () {
      final r = RepeatCommand.parse('  #2   smile  ')!;
      expect(r.count, 2);
      expect(r.body, 'smile');
    });

    test('is not a repeat without a body, a count, or with a zero count', () {
      expect(RepeatCommand.parse('#15'), isNull);
      expect(RepeatCommand.parse('#15   '), isNull);
      expect(RepeatCommand.parse('#al bt buy beer'), isNull);
      expect(RepeatCommand.parse('#0 smile'), isNull);
      expect(RepeatCommand.parse('15 smile'), isNull);
      expect(RepeatCommand.parse('say #15 beers'), isNull);
    });
  });
}
