import 'package:ancient_anguish_client/providers/battle_provider.dart';
import 'package:ancient_anguish_client/providers/room_targets_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/providers/target_provider.dart';
import 'package:ancient_anguish_client/services/parser/battle_text_classifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  TargetNotifier target() => container.read(targetProvider.notifier);
  String? current() => container.read(targetProvider);

  /// Commits a room block listing [creatures], one line each.
  void enterRoom(List<String> creatures) {
    final rooms = container.read(roomTargetsProvider.notifier);
    rooms.processLine('Pine forest (n,e,s,w)');
    for (final c in creatures) {
      rooms.processLine(c);
    }
    rooms.processLine('');
  }

  setUp(() {
    container = ProviderContainer();
    // Build the notifier first so it is listening when rooms commit.
    container.read(targetProvider);
  });
  tearDown(() => container.dispose());

  group('helpers', () {
    test('targetBaseKeyword strips the ordinal', () {
      expect(targetBaseKeyword('orc 2'), 'orc');
      expect(targetBaseKeyword('orc'), 'orc');
    });

    test('targetKeywordFromName takes the lower-case head noun', () {
      expect(targetKeywordFromName('Ship rat'), 'rat');
      expect(targetKeywordFromName('Nurse'), 'nurse');
      expect(targetKeywordFromName('  '), isNull);
    });
  });

  group('cycling', () {
    test('Tab walks the room in order, duplicates with ordinals, and wraps',
        () {
      enterRoom(['An orc.', 'A wild boar.', 'An orc.']);
      target().next();
      expect(current(), 'orc');
      target().next();
      expect(current(), 'orc 2');
      target().next();
      expect(current(), 'boar');
      target().next();
      expect(current(), 'orc');
    });

    test('Shift+Tab goes backwards and starts at the last', () {
      enterRoom(['An orc.', 'A wild boar.']);
      target().previous();
      expect(current(), 'boar');
      target().previous();
      expect(current(), 'orc');
      target().previous();
      expect(current(), 'boar');
    });

    test('ignored keywords are skipped', () {
      container.read(settingsProvider.notifier).addIgnoredKillTarget('orc');
      enterRoom(['An orc.', 'A wild boar.', 'An orc.']);
      target().next();
      expect(current(), 'boar');
      target().next();
      expect(current(), 'boar');
    });

    test('an empty cycle clears the target', () {
      target().set('orc');
      target().next();
      expect(current(), isNull);
    });
  });

  group('setting and ignoring', () {
    test('set normalises', () {
      target().set('  Orc  2 ');
      expect(current(), 'orc 2');
      target().clear();
      expect(current(), isNull);
    });

    test('X ignores the keyword and moves to the next creature', () {
      enterRoom(['A wild boar.', 'An orc.', 'An orc.', 'A giant tick.']);
      target().set('orc');
      expect(target().ignoreCurrent(), 'orc');
      expect(container.read(settingsProvider).ignoredKillTargets,
          contains('orc'));
      expect(current(), 'tick');
    });

    test('X on the last candidate wraps to the first remaining', () {
      enterRoom(['A wild boar.', 'An orc.']);
      target().set('orc');
      target().ignoreCurrent();
      expect(current(), 'boar');
    });

    test('X with nothing left clears, and with no target does nothing', () {
      enterRoom(['An orc.']);
      expect(target().ignoreCurrent(), isNull);
      target().set('orc');
      target().ignoreCurrent();
      expect(current(), isNull);
    });
  });

  group('battle', () {
    const hit = BattleLineMatch(
        kind: BattleLineKind.incomingHit, opponent: 'Ship rat');

    test('a fight with no target adopts the opponent head noun', () {
      target().onBattleLine(hit);
      expect(current(), 'rat');
    });

    test('a fight does not replace an existing target', () {
      target().set('orc');
      target().onBattleLine(hit);
      expect(current(), 'orc');
    });

    test('an ignored opponent is not auto-targeted', () {
      container.read(settingsProvider.notifier).addIgnoredKillTarget('rat');
      target().onBattleLine(hit);
      expect(current(), isNull);
    });

    test('a death naming the keyword clears, even for an ordinal target', () {
      target().set('orc 2');
      target().onBattleLine(const BattleLineMatch(
          kind: BattleLineKind.resolution, opponent: 'Orc'));
      expect(current(), isNull);
    });

    test('a death of something else keeps the target', () {
      target().set('orc');
      target().onBattleLine(const BattleLineMatch(
          kind: BattleLineKind.resolution, opponent: 'Ship rat'));
      expect(current(), 'orc');
    });

    test('a death line never sets a target', () {
      target().onBattleLine(const BattleLineMatch(
          kind: BattleLineKind.resolution, opponent: 'Orc'));
      expect(current(), isNull);
    });
  });

  group('rooms', () {
    test('entering a room without the target clears it', () {
      enterRoom(['An orc.']);
      target().set('orc');
      enterRoom(['A wild boar.']);
      expect(current(), isNull);
    });

    test('a room that still holds the target keeps it', () {
      enterRoom(['An orc.']);
      target().set('orc');
      enterRoom(['An orc.', 'A wild boar.']);
      expect(current(), 'orc');
    });

    test('in a fight the target survives a room change', () {
      enterRoom(['An orc.']);
      target().set('orc');
      container.read(battleStateProvider.notifier).onBattlePatternDetected();
      enterRoom(['A wild boar.']);
      expect(current(), 'orc');
      container.read(battleStateProvider.notifier).reset();
    });
  });

  group('ignore list', () {
    test('ignoring the current target elsewhere drops it', () {
      enterRoom(['An orc.', 'A wild boar.']);
      target().set('orc 2');
      // The long-press "Stop highlighting this" path.
      container.read(settingsProvider.notifier).addIgnoredKillTarget('orc');
      expect(current(), isNull);
      target().next();
      expect(current(), 'boar');
    });

    test('an ignored creature can still be chosen from the Kill picker', () {
      container.read(settingsProvider.notifier).addIgnoredKillTarget('orc');
      target().set('orc');
      expect(current(), 'orc');
      container.read(settingsProvider.notifier).addIgnoredKillTarget('rat');
      expect(current(), 'orc');
    });
  });
}
