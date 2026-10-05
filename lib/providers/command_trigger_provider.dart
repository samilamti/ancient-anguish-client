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

final userActivityTrackerProvider =
    Provider<UserActivityTracker>((_) => UserActivityTracker.instance);
