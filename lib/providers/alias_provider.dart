import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alias_rule.dart';
import '../services/alias/alias_engine.dart';
import '../services/config/markdown_config_parser.dart';
import '../services/storage/storage_service.dart';
import 'storage_provider.dart';

/// Provides the singleton [AliasEngine].
final aliasEngineProvider = Provider<AliasEngine>((ref) {
  return AliasEngine();
});

/// Provides the list of alias rules (for UI binding).
final aliasRulesProvider =
    NotifierProvider<AliasRulesNotifier, List<AliasRule>>(
        AliasRulesNotifier.new);

/// Manages alias rules: add, remove, update, toggle.
///
/// Persists rules to `Aliases.md` in the app documents directory.
class AliasRulesNotifier extends Notifier<List<AliasRule>> {
  late final AliasEngine _engine;
  late final StorageService _storage;

  static const _fileName = 'Aliases.md';
  static const _legacyFileName = 'aliases.md';

  @override
  List<AliasRule> build() {
    _engine = ref.read(aliasEngineProvider);
    _storage = ref.read(storageServiceProvider);
    final defaults = AliasEngine.defaultAliases();
    _engine.setRules(defaults);
    // Fire-and-forget: load saved rules from disk, replacing defaults.
    _loadFromDisk();
    return List.unmodifiable(defaults);
  }

  Future<void> _loadFromDisk() async {
    try {
      final contents = await _storage.readFile(_fileName);
      if (contents.trim().isNotEmpty) {
        final rules = MarkdownConfigParser.parseAliases(contents);
        if (rules.isNotEmpty) {
          _engine.setRules(rules);
          state = List.unmodifiable(_engine.rules);
          return;
        }
      }

      // Migration: try old aliases.md format.
      final legacyContents = await _storage.readFile(_legacyFileName);
      if (legacyContents.trim().isNotEmpty) {
        final rules = MarkdownConfigParser.parseLegacyAliases(legacyContents);
        if (rules.isNotEmpty) {
          _engine.setRules(rules);
          state = List.unmodifiable(_engine.rules);
          _saveToDisk(); // Re-save in new format.
        }
      }
    } catch (e) {
      debugPrint('AliasRulesNotifier._loadFromDisk: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final md = MarkdownConfigParser.serializeAliases(_engine.rules);
      await _storage.writeFile(_fileName, md);
    } catch (e) {
      debugPrint('AliasRulesNotifier._saveToDisk: $e');
    }
  }

  /// Adds a new alias rule.
  void addRule(AliasRule rule) {
    _engine.addRule(rule);
    state = List.unmodifiable(_engine.rules);
    _saveToDisk();
  }

  /// Removes an alias rule by ID.
  void removeRule(String id) {
    _engine.removeRule(id);
    state = List.unmodifiable(_engine.rules);
    _saveToDisk();
  }

  /// Updates an existing alias rule.
  void updateRule(AliasRule updated) {
    _engine.updateRule(updated);
    state = List.unmodifiable(_engine.rules);
    _saveToDisk();
  }

  /// Toggles an alias rule's enabled state.
  void toggleRule(String id) {
    final rule = _engine.getRule(id);
    if (rule != null) {
      _engine.updateRule(rule.copyWith(enabled: !rule.enabled));
      state = List.unmodifiable(_engine.rules);
      _saveToDisk();
    }
  }

  /// Replaces all rules.
  void setRules(List<AliasRule> rules) {
    _engine.setRules(rules);
    state = List.unmodifiable(_engine.rules);
    _saveToDisk();
  }
}
