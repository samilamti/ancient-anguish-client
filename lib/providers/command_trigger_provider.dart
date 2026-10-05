import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/text_link_rule.dart';
import '../services/trigger/command_trigger_engine.dart';
import '../services/user_activity_tracker.dart';
import 'text_link_rule_provider.dart';

export 'local_features_provider.dart';

/// Command trigger rules, persisted to `Command Triggers.json`. Same model and
/// notifier as text link rules; no bundled defaults.
final commandTriggerRulesProvider =
    NotifierProvider<TextLinkRulesNotifier, List<TextLinkRule>>(
  () => TextLinkRulesNotifier(
    fileName: 'Command Triggers.json',
    defaults: const [],
  ),
);

/// Rebuilt whenever the rule list changes, which also resets cooldowns.
final commandTriggerEngineProvider = Provider<CommandTriggerEngine>((ref) {
  return CommandTriggerEngine(ref.watch(commandTriggerRulesProvider));
});

/// The toolbar's "Instant Triggers" toggle. ON: triggers fire on every match
/// at once, whatever the player is doing. OFF (the default, and the state on
/// every launch): idle gate, fire delay and shared cooldown apply.
final instantTriggersProvider =
    NotifierProvider<InstantTriggersNotifier, bool>(InstantTriggersNotifier.new);

class InstantTriggersNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final userActivityTrackerProvider =
    Provider<UserActivityTracker>((_) => UserActivityTracker.instance);
