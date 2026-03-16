import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trigger_rule.dart';
import '../services/config/markdown_config_parser.dart';
import '../services/storage/storage_service.dart';
import '../services/trigger/trigger_engine.dart';
import 'storage_provider.dart';

/// Provides the singleton [TriggerEngine].
final triggerEngineProvider = Provider<TriggerEngine>((ref) {
  return TriggerEngine();
});

/// Provides the list of trigger rules (for UI binding).
final triggerRulesProvider =
    NotifierProvider<TriggerRulesNotifier, List<TriggerRule>>(
        TriggerRulesNotifier.new);

/// Manages trigger rules: add, remove, update, toggle, reorder.
///
/// Persists rules to `Immersions.md` in the app documents directory.
class TriggerRulesNotifier extends Notifier<List<TriggerRule>> {
  late final TriggerEngine _engine;
  late final StorageService _storage;

  @override
  List<TriggerRule> build() {
    _engine = ref.read(triggerEngineProvider);
    _storage = ref.read(storageServiceProvider);
    final defaultRules = defaults();
    _engine.setRules(defaultRules);
    // Fire-and-forget: load saved rules from disk, replacing defaults.
    _loadFromDisk();
    return List.unmodifiable(defaultRules);
  }

  static List<TriggerRule> defaults() {
    return [
      TriggerRule(
        id: 'hl_01',
        name: 'Tells (messages)',
        pattern: r'\w+ tells you:',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFF00FF00),
        highlightBold: true,
        highlightWholeLine: true,
      ),
      TriggerRule(
        id: 'hl_02',
        name: 'Shouts',
        pattern: r'\w+ shouts:',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFF6600),
        highlightBold: true,
        highlightWholeLine: true,
      ),
      TriggerRule(
        id: 'hl_03',
        name: 'Being attacked',
        pattern: r'attacks you|hits you|misses you|stabs you',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFF0000),
        highlightBold: true,
      ),
      TriggerRule(
        id: 'hl_04',
        name: 'Low HP warning',
        pattern: r'You are in bad shape|You are near death',
        action: TriggerAction.highlight,
        highlightForeground: const Color(0xFFFFFFFF),
        highlightBackground: const Color(0xFFCC0000),
        highlightBold: true,
        highlightWholeLine: true,
      ),
    ];
  }

  static const _fileName = 'Immersions.md';
  static const _legacyFileName = 'triggers.md';

  Future<void> _loadFromDisk() async {
    try {
      final contents = await _storage.readFile(_fileName);
      if (contents.trim().isNotEmpty) {
        final rules = MarkdownConfigParser.parseImmersions(contents);
        if (rules.isNotEmpty) {
          _engine.setRules(rules);
          state = List.unmodifiable(_engine.rules);
          return;
        }
      }

      // Migration: try old triggers.md format.
      final legacyContents = await _storage.readFile(_legacyFileName);
      if (legacyContents.trim().isNotEmpty) {
        final rules = MarkdownConfigParser.parseLegacyTriggers(legacyContents);
        if (rules.isNotEmpty) {
          _engine.setRules(rules);
          state = List.unmodifiable(_engine.rules);
          _saveToDisk(); // Re-save in new format.
        }
      }
    } catch (e) {
      debugPrint('TriggerRulesNotifier._loadFromDisk: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final md = MarkdownConfigParser.serializeImmersions(_engine.rules);
      await _storage.writeFile(_fileName, md);
    } catch (e) {
      debugPrint('TriggerRulesNotifier._saveToDisk: $e');
    }
  }

  /// Adds a new trigger rule.
  void addRule(TriggerRule rule) {
    _engine.addRule(rule);
    state = List.unmodifiable(_engine.rules);
    _saveToDisk();
  }

  /// Removes a trigger rule by ID.
  void removeRule(String id) {
    _engine.removeRule(id);
    state = List.unmodifiable(_engine.rules);
    _saveToDisk();
  }

  /// Updates an existing trigger rule.
  void updateRule(TriggerRule updated) {
    _engine.updateRule(updated);
    state = List.unmodifiable(_engine.rules);
    _saveToDisk();
  }

  /// Toggles a trigger rule's enabled state.
  void toggleRule(String id) {
    final rule = _engine.getRule(id);
    if (rule != null) {
      _engine.updateRule(rule.copyWith(enabled: !rule.enabled));
      state = List.unmodifiable(_engine.rules);
      _saveToDisk();
    }
  }

  /// Replaces all rules (e.g., after importing).
  void setRules(List<TriggerRule> rules) {
    _engine.setRules(rules);
    state = List.unmodifiable(_engine.rules);
    _saveToDisk();
  }
}
