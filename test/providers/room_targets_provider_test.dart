import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/room_targets_provider.dart';

/// Feeds a multi-line MUD output block through the notifier and returns
/// the resulting committed targets list.
List<String> _runBlock(RoomTargetsNotifier notifier, String block) {
  for (final line in block.split('\n')) {
    notifier.processLine(line);
  }
  // Commit the in-flight block by emitting a blank line (mimics what the
  // prompt arriving in the real stream would do).
  notifier.processLine('');
  return notifier.state;
}

void main() {
  late ProviderContainer container;
  late RoomTargetsNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(roomTargetsProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('RoomTargetsNotifier - the four reference examples', () {
    test('Nice forest → frog', () {
      expect(
        _runBlock(notifier, '''
Nice forest (n,e,s,w)
A green frog.
'''),
        ['frog'],
      );
    });

    test('Pine forest → tick, boar', () {
      expect(
        _runBlock(notifier, '''
Pine forest (n,e,s,w)
A giant tick.
A wild boar.
'''),
        ['tick', 'boar'],
      );
    });

    test('Light pine forest → eagle', () {
      expect(
        _runBlock(notifier, '''
Light pine forest (n,e,s)
A giant eagle.
'''),
        ['eagle'],
      );
    });

    test('Top of slope → warrior', () {
      expect(
        _runBlock(notifier, '''
Top of slope (n,e,sw,nw)
A Goblin Warrior.
'''),
        ['warrior'],
      );
    });
  });

  group('RoomTargetsNotifier - block boundaries', () {
    test('a new room header replaces the previous targets', () {
      _runBlock(notifier, '''
Pine forest (n,e,s,w)
A giant tick.
A wild boar.
''');
      expect(notifier.state, ['tick', 'boar']);

      notifier.processLine('Nice forest (n,e,s,w)');
      notifier.processLine('A green frog.');
      notifier.processLine('');
      expect(notifier.state, ['frog']);
    });

    test('lines outside a room block are ignored', () {
      notifier.processLine('A wandering merchant.');
      notifier.processLine('A street sign.');
      expect(notifier.state, isEmpty);
    });

    test('NPC lines anywhere in the block are captured, not just immediately after the header', () {
      _runBlock(notifier, '''
Pine forest (n,e,s,w)
The trees rustle in the wind.
You hear a distant howl.
A giant tick.
The grass is damp underfoot.
A wild boar.
''');
      expect(notifier.state, ['tick', 'boar']);
    });

    test('duplicates within one room are deduped', () {
      _runBlock(notifier, '''
Pine forest (n,e,s,w)
A giant tick.
A giant tick.
A wild boar.
''');
      expect(notifier.state, ['tick', 'boar']);
    });
  });
}
