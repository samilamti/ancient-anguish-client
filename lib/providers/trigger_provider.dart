import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trigger_rule.dart';
import '../services/trigger/trigger_engine.dart';

/// Provides the singleton [TriggerEngine].
final triggerEngineProvider = Provider<TriggerEngine>((ref) {
  return TriggerEngine();
});

/// Provides the list of trigger rules (for UI binding).
final triggerRulesProvider =
    NotifierProvider<TriggerRulesNotifier, List<TriggerRule>>(
        TriggerRulesNotifier.new);

/// Manages trigger rules: add, remove, update, toggle, reorder.
class TriggerRulesNotifier extends Notifier<List<TriggerRule>> {
  late final TriggerEngine _engine;

  @override
  List<TriggerRule> build() {
    _engine = ref.read(triggerEngineProvider);
    return _loadDefaults();
  }

  List<TriggerRule> _loadDefaults() {
    final defaults = [
      TriggerRule(
        id: 'trig_tells',
        name: 'Tells (messages)',
        pattern: r'\w+ tells you:',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFF00FF00),
        highlightBold: true,
        highlightWholeLine: true,
      ),
      TriggerRule(
        id: 'trig_shout',
        name: 'Shouts',
        pattern: r'\w+ shouts:',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFF6600),
        highlightBold: true,
        highlightWholeLine: true,
      ),
      TriggerRule(
        id: 'trig_attacked',
        name: 'Being attacked',
        pattern: r'attacks you|hits you|misses you|stabs you',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFF0000),
        highlightBold: true,
      ),
      TriggerRule(
        id: 'trig_lowhp',
        name: 'Low HP warning',
        pattern: r'You are in bad shape|You are near death',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFFFFFF),
        highlightBackground: const Color(0xFFCC0000),
        highlightBold: true,
        highlightWholeLine: true,
      ),
    ];

    _engine.setRules(defaults);
    return List.unmodifiable(defaults);
  }

  /// Adds a new trigger rule.
  void addRule(TriggerRule rule) {
    _engine.addRule(rule);
    state = List.unmodifiable(_engine.rules);
  }

  /// Removes a trigger rule by ID.
  void removeRule(String id) {
    _engine.removeRule(id);
    state = List.unmodifiable(_engine.rules);
  }

  /// Updates an existing trigger rule.
  void updateRule(TriggerRule updated) {
    _engine.updateRule(updated);
    state = List.unmodifiable(_engine.rules);
  }

  /// Toggles a trigger rule's enabled state.
  void toggleRule(String id) {
    final rule = _engine.getRule(id);
    if (rule != null) {
      _engine.updateRule(rule.copyWith(enabled: !rule.enabled));
      state = List.unmodifiable(_engine.rules);
    }
  }

  /// Replaces all rules (e.g., after importing from JSON).
  void setRules(List<TriggerRule> rules) {
    _engine.setRules(rules);
    state = List.unmodifiable(_engine.rules);
  }
}
