import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/meter_condition.dart';
import 'package:ancient_anguish_client/models/text_link_rule.dart';
import 'package:ancient_anguish_client/providers/command_trigger_provider.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';
import 'package:ancient_anguish_client/services/trigger/command_trigger_engine.dart';

import 'fake_connection_service.dart';

/// Meter triggers through the real terminal buffer: a prompt that moves HP
/// into a band must send the trigger's command, in Instant mode (no timers).
void main() {
  late FakeConnectionService fake;

  const potion = TextLinkRule(
    id: 'ctr_potion',
    name: 'Potion',
    pattern: '',
    commandTemplate: 'drink potion',
    meter: MeterCondition(meter: Meter.hp, band: 'orange'),
    skipWhileMoving: false,
  );

  Future<ProviderContainer> start({bool localFeatures = true}) async {
    fake = FakeConnectionService();
    final c = ProviderContainer(overrides: [
      connectionServiceProvider.overrideWithValue(fake),
      promptParserProvider.overrideWithValue(PromptParser()),
      areaDetectorProvider.overrideWith((ref) => Future.value(AreaDetector())),
      unifiedAreaConfigProvider
          .overrideWith((ref) => Future.value(UnifiedAreaConfigManager())),
      localFeaturesAvailableProvider.overrideWith((ref) async => localFeatures),
      commandTriggerEngineProvider
          .overrideWith((ref) => CommandTriggerEngine([potion])),
    ]);
    await c.read(localFeaturesAvailableProvider.future);
    c.read(terminalBufferProvider.notifier).setLoginDetected();
    c.read(instantTriggersProvider.notifier).toggle();
    return c;
  }

  Future<void> prompt(ProviderContainer c, int hp) async {
    c.read(gameStateProvider.notifier).processLine('$hp/100:50/50>');
    await Future<void>.delayed(Duration.zero);
  }

  test('fires once when HP turns orange, not on every prompt in it', () async {
    final c = await start();
    addTearDown(c.dispose);
    await prompt(c, 90); // first prompt: max was unknown, nothing fires
    expect(fake.sentCommands, isEmpty);
    await prompt(c, 55);
    expect(fake.sentCommands, ['drink potion']);
    await prompt(c, 40);
    expect(fake.sentCommands, ['drink potion']);
  });

  test('login with HP already orange does not fire', () async {
    final c = await start();
    addTearDown(c.dispose);
    await prompt(c, 50);
    expect(fake.sentCommands, isEmpty);
  });

  test('nothing without the local-features marker', () async {
    final c = await start(localFeatures: false);
    addTearDown(c.dispose);
    await prompt(c, 90);
    await prompt(c, 55);
    expect(fake.sentCommands, isEmpty);
  });
}
