import 'package:ancient_anguish_client/services/speedwalk/speed_walk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeedWalkPath.parse', () {
    test('21ne is 21 norths then one east', () {
      final p = SpeedWalkPath.parse('21ne')!;
      expect(p.moves, hasLength(22));
      expect(p.moves.take(21).every((m) => m == 'n'), isTrue);
      expect(p.moves.last, 'e');
    });

    test('mixed counts, case and whitespace', () {
      expect(SpeedWalkPath.parse(' 2N3wu ')!.moves,
          ['n', 'n', 'w', 'w', 'w', 'u']);
    });

    test('plain directions and commands are left alone', () {
      for (final s in ['ne', 'sw', 'n', 'u', 'look', '2', '0n', 'n2', '#3 n',
          '1n', '3x', 'kill 2']) {
        expect(SpeedWalkPath.parse(s), isNull, reason: s);
      }
    });

    test('refuses a walk longer than the cap', () {
      expect(SpeedWalkPath.parse('201n'), isNull);
      expect(SpeedWalkPath.parse('200n'), isNotNull);
    });
  });

  group('SpeedWalkTracker', () {
    test('swallows until the last room header', () {
      final t = SpeedWalkTracker(3);
      expect(t.feed('Forest path (n,s)'), SpeedWalkLine.swallow);
      expect(t.feed('A wolf is here.'), SpeedWalkLine.swallow);
      expect(t.feed('Forest path (n,s)'), SpeedWalkLine.swallow);
      expect(t.feed('Clearing (s,e)'), SpeedWalkLine.arrived);
    });

    test('one refusal is tolerated, two abort', () {
      final t = SpeedWalkTracker(5);
      expect(t.feed('What?'), SpeedWalkLine.swallow);
      expect(t.feed("There's no such exit."), SpeedWalkLine.aborted);
    });

    test('recognises the usual refusals', () {
      for (final s in ['What?', 'What ?', "There's no such exit.",
          "You can't go that way.", 'There is no exit in that direction.']) {
        expect(SpeedWalkTracker.isRefusal(s), isTrue, reason: s);
      }
      expect(SpeedWalkTracker.isRefusal('What a lovely day.'), isFalse);
    });
  });
}
