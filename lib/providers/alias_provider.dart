import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alias_rule.dart';
import '../services/alias/alias_engine.dart';

/// Provides the singleton [AliasEngine].
final aliasEngineProvider = Provider<AliasEngine>((ref) {
  return AliasEngine();
});

/// Provides the list of alias rules (for UI binding).
final aliasRulesProvider =
    NotifierProvider<AliasRulesNotifier, List<AliasRule>>(
        AliasRulesNotifier.new);

/// Manages alias rules: add, remove, update, toggle.
class AliasRulesNotifier extends Notifier<List<AliasRule>> {
  late final AliasEngine _engine;

  @override
  List<AliasRule> build() {
    _engine = ref.read(aliasEngineProvider);
    return _loadDefaults();
  }

  List<AliasRule> _loadDefaults() {
    final defaults = AliasEngine.defaultAliases();
    _engine.setRules(defaults);
    return List.unmodifiable(defaults);
  }

  /// Adds a new alias rule.
  void addRule(AliasRule rule) {
    _engine.addRule(rule);
    state = List.unmodifiable(_engine.rules);
  }

  /// Removes an alias rule by ID.
  void removeRule(String id) {
    _engine.removeRule(id);
    state = List.unmodifiable(_engine.rules);
  }

  /// Updates an existing alias rule.
  void updateRule(AliasRule updated) {
    _engine.updateRule(updated);
    state = List.unmodifiable(_engine.rules);
  }

  /// Toggles an alias rule's enabled state.
  void toggleRule(String id) {
    final rule = _engine.getRule(id);
    if (rule != null) {
      _engine.updateRule(rule.copyWith(enabled: !rule.enabled));
      state = List.unmodifiable(_engine.rules);
    }
  }

  /// Replaces all rules.
  void setRules(List<AliasRule> rules) {
    _engine.setRules(rules);
    state = List.unmodifiable(_engine.rules);
  }
}
