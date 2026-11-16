import 'package:ancient_anguish_client/models/battle_stats.dart';
import 'package:ancient_anguish_client/providers/battle_stats_provider.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/kata_provider.dart';
import 'package:ancient_anguish_client/providers/local_features_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';
import 'package:ancient_anguish_client/services/parser/battle_text_classifier.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Service extends TcpConnectionService {
  final List<String> sent = [];

  @override
  bool get isConnected => true;

  @override
  void sendCommand(String command) => sent.add(command);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Service service;
  late ProviderContainer c;

  void setUpContainer(FakeAsync async, List<String> slots) {
    service = _Service();
    c = ProviderContainer(overrides: [
      connectionServiceProvider.overrideWithValue(service),
      localFeaturesAvailableProvider.overrideWith((ref) async => true),
    ]);
    c.read(localFeaturesAvailableProvider);
    async.flushMicrotasks();
    for (var i = 0; i < slots.length; i++) {
      c.read(settingsProvider.notifier).setKataSlot(i, slots[i]);
    }
    c.read(kataProvider.notifier).arm();
  }

  test('runs one slot per second from the first blow and loops', () {
    fakeAsync((async) {
      setUpContainer(async, ['kick', '', 'punch']);
      final kata = c.read(kataProvider.notifier);
      expect(c.read(kataProvider).armed, isTrue);
      // Switching on with saved slots still shows the window.
      expect(c.read(kataWindowProvider).open, isTrue);
      expect(service.sent, isEmpty);

      kata.onCombatLine(BattleLineKind.yourHit);
      expect(service.sent, ['kick']);
      expect(c.read(kataProvider).slot, 1);

      // Further blows in the same fight don't restart it.
      kata.onCombatLine(BattleLineKind.incomingHit);
      async.elapse(const Duration(seconds: 1));
      expect(service.sent, ['kick']);
      async.elapse(const Duration(seconds: 1));
      expect(service.sent, ['kick', 'punch']);
      async.elapse(const Duration(seconds: 1));
      expect(service.sent, ['kick', 'punch', 'kick']);

      // A kill ends it; the next blow starts again at slot 1.
      kata.onCombatLine(BattleLineKind.resolution);
      expect(c.read(kataProvider).performing, isFalse);
      async.elapse(const Duration(seconds: 3));
      expect(service.sent, ['kick', 'punch', 'kick']);
      kata.onCombatLine(BattleLineKind.yourMiss);
      expect(service.sent.last, 'kick');
      expect(service.sent, hasLength(4));
      c.dispose();
    });
  });

  test('stops when combat goes quiet', () {
    fakeAsync((async) {
      setUpContainer(async, ['kick']);
      c.read(battleStatsProvider.notifier).record(
            const BattleLineMatch(kind: BattleLineKind.yourHit),
          );
      c.read(kataProvider.notifier).onCombatLine(BattleLineKind.yourHit);
      expect(c.read(kataProvider).performing, isTrue);
      async.elapse(BattleStatsNotifier.battleTimeout +
          const Duration(milliseconds: 100));
      expect(c.read(battleStatsProvider), isA<BattleStats>());
      expect(c.read(kataProvider).performing, isFalse);
      final sent = service.sent.length;
      async.elapse(const Duration(seconds: 3));
      expect(service.sent, hasLength(sent));
      c.dispose();
    });
  });

  test('does nothing while off, and refuses to arm with no actions', () {
    fakeAsync((async) {
      setUpContainer(async, []);
      expect(c.read(kataProvider).armed, isFalse);
      c.read(kataProvider.notifier).onCombatLine(BattleLineKind.yourHit);
      async.elapse(const Duration(seconds: 2));
      expect(service.sent, isEmpty);
      expect(c.read(kataWindowProvider).open, isTrue);
      c.dispose();
    });
  });

  test('disarm stops a running Kata', () {
    fakeAsync((async) {
      setUpContainer(async, ['kick']);
      c.read(kataProvider.notifier).onCombatLine(BattleLineKind.yourHit);
      c.read(kataProvider.notifier).disarm();
      async.elapse(const Duration(seconds: 3));
      expect(service.sent, ['kick']);
      expect(c.read(kataProvider).armed, isFalse);
      c.dispose();
    });
  });
}
