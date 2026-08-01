import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/text_link_rule.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart'
    show areaDetectorProvider, promptParserProvider;
import 'package:ancient_anguish_client/providers/text_link_rule_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/protocol/telnet/telnet_events.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';

import 'fake_connection_service.dart';

/// What Ctrl/Cmd+K and Ctrl/Cmd+T reach for.
///
/// The two shortcuts exist because the generic "most recent link" could not
/// reach a text-link rule once a screen of red kill links had scrolled over
/// it — so the split has to hold with both kinds in the same buffer.
void main() {
  late FakeConnectionService fakeService;
  late ProviderContainer container;

  setUp(() {
    fakeService = FakeConnectionService();
    container = ProviderContainer(overrides: [
      connectionServiceProvider.overrideWithValue(fakeService),
      promptParserProvider.overrideWithValue(PromptParser()),
      areaDetectorProvider.overrideWith((ref) => Future.value(AreaDetector())),
      unifiedAreaConfigProvider
          .overrideWith((ref) => Future.value(UnifiedAreaConfigManager())),
    ]);
    addTearDown(container.dispose);
    // A rule that turns a closed door into a tappable `open dark door`.
    // Seeded in memory only, so the developer's own rules on disk can't
    // decide what this test sees.
    container.read(textLinkRulesProvider.notifier).seedDemoRules(const [
      TextLinkRule(
        id: 'r1',
        name: 'Open a closed door',
        pattern: r'The (\w+) door is closed\.',
        commandTemplate: r'open $1 door',
      ),
    ]);
    container.read(terminalBufferProvider.notifier);
  });

  Future<void> feed(Iterable<String> lines) async {
    fakeService.emit(TelnetDataEvent(
      Uint8List.fromList('${lines.join('\r\n')}\r\n'.codeUnits),
    ));
    await Future.microtask(() {});
    await Future.microtask(() {});
  }

  TerminalBufferNotifier buffer() =>
      container.read(terminalBufferProvider.notifier);

  test('with only a text link, K finds nothing and T finds it', () async {
    await feed(['The dark door is closed.']);

    expect(buffer().mostRecentTextLinkCommand, 'open dark door');
    expect(buffer().mostRecentKillCommand, isNull);
    expect(buffer().mostRecentLinkCommand, 'open dark door');
  });

  test('a kill link after a text link does not bury it', () async {
    await feed(['The dark door is closed.']);
    await feed(['Light pine forest (n,e,s)', 'A giant eagle.']);

    // The generic shortcut can only see the newest link of any kind…
    expect(buffer().mostRecentLinkCommand, 'kill eagle');
    // …which is exactly why the two split ones exist.
    expect(buffer().mostRecentKillCommand, 'kill eagle');
    expect(buffer().mostRecentTextLinkCommand, 'open dark door');
  });

  test('each shortcut tracks its own newest link', () async {
    await feed(['Light pine forest (n,e,s)', 'A giant eagle.']);
    await feed(['The dark door is closed.']);

    expect(buffer().mostRecentKillCommand, 'kill eagle');
    expect(buffer().mostRecentTextLinkCommand, 'open dark door');
  });

  test('an empty buffer offers neither', () {
    expect(buffer().mostRecentKillCommand, isNull);
    expect(buffer().mostRecentTextLinkCommand, isNull);
  });
}
