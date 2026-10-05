import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/text_link_rule.dart';
import '../services/trigger/command_trigger_engine.dart';
import '../services/user_activity_tracker.dart';
import 'text_link_rule_provider.dart';

/// Marker asset that switches command triggers on. The file is gitignored, so
/// a checkout (and therefore every CI build) never has it: the feature exists
/// only on a machine where someone has created it by hand. Its contents are
/// ignored. The release scripts refuse to build while it exists, so a local
/// store build can't carry it either.
const commandTriggersMarkerAsset = 'assets/local/command_triggers.enabled';

/// Whether this build carries [commandTriggersMarkerAsset].
final commandTriggersAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    await rootBundle.load(commandTriggersMarkerAsset);
    return true;
  } catch (_) {
    return false;
  }
});

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
