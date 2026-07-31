import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/battle_filter_mode.dart';
import 'package:ancient_anguish_client/models/connection_info.dart';
import 'package:ancient_anguish_client/protocol/telnet/telnet_events.dart';
import 'package:ancient_anguish_client/providers/battle_stats_provider.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart'
    show areaDetectorProvider, promptParserProvider;
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/connection/connection_interface.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';

/// End-to-end tests for battle-text filtering: real bytes into
/// [TerminalBufferNotifier], assertions on what the player ends up seeing.
///
/// The reference transcript is 22 lines of a fight against a Nurse. Under
/// `off` all 22 land in the buffer; the whole point of the other two modes is
/// that the number stops scaling with the length of the fight.
void main() {
  late _FakeConnectionService fakeService;
  late ProviderContainer container;

  /// The transcript this feature was built from, as it arrives off the socket.
  const combat = [
    "Mummy pierced Nurse's head keenly.",
    "You pounded Nurse's leg heartlessly.",
    'Nurse missed you.',
    "Mummy pricked Nurse's head.",
    "You pounded Nurse's head heartlessly.",
    "You duck your head quickly as Nurse's blow flies over you.",
    'Nurse missed you.',
    "Mummy lacerated Nurse's body.",
    'You missed.',
    'HP:  88  SP:  79',
    'Nurse pounded your head heartlessly.',
    "Mummy impaled Nurse's body sharply.",
    "You pounded Nurse's body heartlessly.",
    'HP:  83  SP:  79',
    'Nurse pounded your body heartlessly.',
    'Mummy missed Nurse.',
    'You missed.',
    'HP:  82  SP:  79',
    'Nurse battered your leg.',
    "Mummy pricked Nurse's head.",
    'Nurse died.',
    'You killed Nurse.',
  ];

  ProviderContainer newContainer(BattleFilterMode mode) {
    final c = ProviderContainer(
      overrides: [
        connectionServiceProvider.overrideWithValue(fakeService),
        promptParserProvider.overrideWithValue(PromptParser()),
        areaDetectorProvider.overrideWith((ref) => Future.value(AreaDetector())),
        unifiedAreaConfigProvider.overrideWith(
            (ref) => Future.value(UnifiedAreaConfigManager())),
      ],
    );
    c.read(settingsProvider.notifier)
        .loadFromJson({'battleFilterMode': mode.storageKey});
    // Attach the notifier so it starts listening.
    c.read(terminalBufferProvider.notifier);
    return c;
  }

  setUp(() => fakeService = _FakeConnectionService());
  tearDown(() => container.dispose());

  Future<void> feed(Iterable<String> lines) async {
    fakeService.emit(
      TelnetDataEvent(
        Uint8List.fromList('${lines.join('\r\n')}\r\n'.codeUnits),
      ),
    );
    await Future.microtask(() {});
    await Future.microtask(() {});
  }

  List<String> buffer() =>
      container.read(terminalBufferProvider).map((l) => l.plainText).toList();

  group('BattleFilterMode.off', () {
    test('every combat line reaches the buffer', () async {
      container = newContainer(BattleFilterMode.off);
      await feed(combat);
      expect(buffer(), combat);
    });
  });

  group('BattleFilterMode.collapse', () {
    test('the fight collapses to one live slot plus its resolution', () async {
      container = newContainer(BattleFilterMode.collapse);
      await feed(combat);

      // 20 filterable lines share a single slot; the two resolution lines are
      // never filtered, so they append normally.
      expect(buffer(), [
        "Mummy pricked Nurse's head.",
        'Nurse died.',
        'You killed Nurse.',
      ]);
    });

    test('the slot always holds the most recent combat line', () async {
      container = newContainer(BattleFilterMode.collapse);

      await feed(combat.take(1));
      expect(buffer().last, "Mummy pierced Nurse's head keenly.");

      await feed(combat.skip(1).take(1));
      expect(buffer().last, "You pounded Nurse's leg heartlessly.");
      expect(buffer(), hasLength(1), reason: 'Replaced, not appended.');

      await feed(combat.skip(2).take(1));
      expect(buffer().last, 'Nurse missed you.');
      expect(buffer(), hasLength(1));
    });

    test('collapsing works across packet boundaries', () async {
      container = newContainer(BattleFilterMode.collapse);
      // One line per data event — the same 20 filterable lines must still
      // share one slot, or a laggy connection defeats the whole feature.
      for (final line in combat) {
        await feed([line]);
      }
      expect(buffer(), hasLength(3));
    });

    test('non-combat output breaks the slot instead of being overwritten',
        () async {
      container = newContainer(BattleFilterMode.collapse);
      await feed([
        "You pounded Nurse's leg heartlessly.",
        'You missed.',
        'Tuinn arrives.', // must survive
        "You pounded Nurse's head heartlessly.",
        'You missed.',
      ]);

      expect(buffer(), [
        'You missed.', // first pair collapsed
        'Tuinn arrives.',
        'You missed.', // second pair collapsed into a fresh slot
      ]);
    });

    test('a lone line that merely resembles combat is never destructive',
        () async {
      container = newContainer(BattleFilterMode.collapse);
      // This satisfies the hit skeleton but is not combat. Collapsing only
      // overwrites a tail that is itself collapsed combat, so it appends and
      // nothing is lost.
      await feed([
        'A quiet clearing.',
        'The healer bandaged your leg gently.',
      ]);
      expect(buffer(), [
        'A quiet clearing.',
        'The healer bandaged your leg gently.',
      ]);
    });
  });

  group('BattleFilterMode.hud', () {
    test('combat leaves the terminal but the resolution stays', () async {
      container = newContainer(BattleFilterMode.hud);
      await feed(combat);

      // The opening line survives on purpose: gagging waits for a second
      // combat line to corroborate the first, so a lone false positive is
      // always visible. That leaves the line where the fight began.
      expect(buffer(), [
        "Mummy pierced Nurse's head keenly.",
        'Nurse died.',
        'You killed Nurse.',
      ]);
    });

    test('the HUD carries the tallies and the latest line', () async {
      container = newContainer(BattleFilterMode.hud);
      await feed(combat);

      final stats = container.read(battleStatsProvider);
      expect(stats.active, isTrue);
      expect(stats.target, 'Nurse');
      expect(stats.hitsDealt, 3);
      expect(stats.hitsTaken, 3);
      expect(stats.rounds, 3);
      expect(stats.hpNow, 82);
      expect(stats.latestLine, 'You killed Nurse.');
    });

    test('non-combat output is untouched', () async {
      container = newContainer(BattleFilterMode.hud);
      await feed([
        "You pounded Nurse's leg heartlessly.",
        "You pounded Nurse's head heartlessly.",
        'Tuinn arrives.',
        'Obvious exits: north and east.',
      ]);

      expect(buffer(), [
        "You pounded Nurse's leg heartlessly.", // fight opener
        'Tuinn arrives.',
        'Obvious exits: north and east.',
      ]);
    });
  });

  group('battle stats regardless of mode', () {
    test('are tracked even with filtering off, so the HUD is ready', () async {
      container = newContainer(BattleFilterMode.off);
      await feed(combat);
      expect(container.read(battleStatsProvider).hitsDealt, 3);
    });
  });
  group("Sami's Ship rat transcript end to end", () {
    /// The fight verbatim, including the two lines that used to score nothing.
    const shipRat = [
      "You slit Ship rat's body.",
      "You chopped Ship rat's body bluntly.",
      "You sliced Ship rat's paw deeply.",
      "You chopped Ship rat's body bluntly.",
      "You clubbed Ship rat's body.",
      "You gashed Ship rat's body.",
      "You pounded Ship rat's body heartlessly.",
      "You slit Ship rat's body.",
      "You sliced Ship rat's body deeply.",
      "You take a quick step backwards, avoiding Ship rat's attack.",
      "You gashed Ship rat's body.",
      "You pierced Ship rat's body keenly.",
      "You pierced Ship rat's body keenly.",
      "You slit Ship rat's body.",
      "You chopped Ship rat's body bluntly.",
      "You chopped Ship rat's head bluntly.",
      'Ship rat predicts your attempt to dodge!',
      "You lacerated Ship rat's head.",
      'Ship rat is vanquished.',
      'You vanquished Ship rat.',
    ];

    test('only the opening line and the two resolutions reach the terminal',
        () async {
      container = newContainer(BattleFilterMode.hud);
      await feed(shipRat);

      // Before the fix every one of the 20 lines landed here, because a
      // two-word creature name never matched the possessive.
      expect(buffer(), [
        "You slit Ship rat's body.",
        'Ship rat is vanquished.',
        'You vanquished Ship rat.',
      ]);
    });

    test('the HUD tallies the fight and names the target', () async {
      container = newContainer(BattleFilterMode.hud);
      await feed(shipRat);

      final stats = container.read(battleStatsProvider);
      expect(stats.target, 'Ship rat');
      // 16 hit lines; the footwork line is an evasion and the read-dodge line
      // scores nothing at all.
      expect(stats.hitsDealt, 16);
      expect(stats.missesAgainst, 1);
      expect(stats.hitsTaken, 0);
      expect(stats.missesDealt, 0);
      expect(stats.resolutions, 2);
    });

    test('chatter keeps the fight alive without scoring', () async {
      container = newContainer(BattleFilterMode.hud);
      await feed(['Ship rat predicts your attempt to dodge!']);

      final stats = container.read(battleStatsProvider);
      expect(stats.startedAt, isNotNull);
      expect(stats.hitsDealt, 0);
      expect(stats.missesDealt, 0);
      expect(stats.hitsTaken, 0);
      expect(stats.missesAgainst, 0);
    });

    test('collapse mode reduces the fight to one slot plus the resolutions',
        () async {
      container = newContainer(BattleFilterMode.collapse);
      await feed(shipRat);

      expect(buffer(), [
        // The collapsed slot holds the last combat line of the run.
        "You lacerated Ship rat's head.",
        'Ship rat is vanquished.',
        'You vanquished Ship rat.',
      ]);
    });
  });
}

class _FakeConnectionService implements MudConnectionService {
  final _events = StreamController<TelnetEvent>.broadcast();
  final _status = StreamController<ConnectionStatus>.broadcast();
  final _rawData = StreamController<Uint8List>.broadcast();

  void emit(TelnetEvent event) => _events.add(event);

  @override
  Stream<TelnetEvent> get events => _events.stream;

  @override
  Stream<ConnectionStatus> get statusStream => _status.stream;

  @override
  Stream<Uint8List> get rawData => _rawData.stream;

  @override
  ConnectionStatus get status => ConnectionStatus.connected;

  @override
  bool get isConnected => true;

  @override
  ConnectionInfo? get connectionInfo => ConnectionInfo.ancientAnguish;

  @override
  Future<void> connect([ConnectionInfo? info]) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> reconnect([ConnectionInfo? info]) async {}

  @override
  void sendCommand(String command) {}

  @override
  void sendBytes(Uint8List bytes) {}

  @override
  void checkAlive() {}

  @override
  Future<void> dispose() async {
    await _events.close();
    await _status.close();
    await _rawData.close();
  }
}
