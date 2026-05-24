import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/text_link_rule.dart';
import '../services/parser/text_link_processor.dart';
import '../services/storage/storage_service.dart';
import 'storage_provider.dart';

/// The list of [TextLinkRule]s, persisted as JSON to disk.
final textLinkRulesProvider =
    NotifierProvider<TextLinkRulesNotifier, List<TextLinkRule>>(
        TextLinkRulesNotifier.new);

/// A derived [TextLinkProcessor] that recompiles whenever the rule list
/// changes. The terminal buffer reads this to promote MUD output spans
/// to tappable command links.
final textLinkProcessorProvider = Provider<TextLinkProcessor>((ref) {
  final rules = ref.watch(textLinkRulesProvider);
  return TextLinkProcessor(rules);
});

/// Manages text-to-link rules. Persists to `Text Link Rules.json` in the
/// app documents directory; falls back to the bundled defaults when the
/// file is missing or empty.
class TextLinkRulesNotifier extends Notifier<List<TextLinkRule>> {
  late final StorageService _storage;
  static const _fileName = 'Text Link Rules.json';

  @override
  List<TextLinkRule> build() {
    _storage = ref.read(storageServiceProvider);
    _loadFromDisk();
    return DefaultTextLinkRules.all();
  }

  Future<void> _loadFromDisk() async {
    try {
      final contents = await _storage.readFile(_fileName);
      if (contents.trim().isEmpty) {
        // First run: seed disk with the defaults so the config screen
        // shows examples the user can edit instead of an empty list.
        await _saveToDisk();
        return;
      }
      final decoded = jsonDecode(contents);
      if (decoded is! List) return;
      final rules = decoded
          .whereType<Map<String, dynamic>>()
          .map(TextLinkRule.fromJson)
          .toList(growable: false);
      state = List.unmodifiable(rules);
    } catch (e) {
      debugPrint('TextLinkRulesNotifier._loadFromDisk: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final encoded =
          const JsonEncoder.withIndent('  ').convert(state.map((r) => r.toJson()).toList());
      await _storage.writeFile(_fileName, encoded);
    } catch (e) {
      debugPrint('TextLinkRulesNotifier._saveToDisk: $e');
    }
  }

  void addRule(TextLinkRule rule) {
    state = List.unmodifiable([...state, rule]);
    _saveToDisk();
  }

  void removeRule(String id) {
    state = List.unmodifiable(state.where((r) => r.id != id).toList());
    _saveToDisk();
  }

  void updateRule(TextLinkRule updated) {
    state = List.unmodifiable(
      state.map((r) => r.id == updated.id ? updated : r).toList(),
    );
    _saveToDisk();
  }

  void toggleRule(String id) {
    final rule = state.firstWhere(
      (r) => r.id == id,
      orElse: () => throw StateError('Rule not found: $id'),
    );
    updateRule(rule.copyWith(enabled: !rule.enabled));
  }

  /// Resets the list back to the bundled defaults. Used by the config
  /// screen's "Reset to defaults" affordance after a confirm dialog.
  void resetToDefaults() {
    state = DefaultTextLinkRules.all();
    _saveToDisk();
  }
}
