import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/area_config_entry.dart';
import '../services/alias/alias_engine.dart';
import '../services/config/markdown_config_parser.dart';
import '../services/storage/storage_service.dart';
import 'settings_provider.dart';
import 'storage_provider.dart';
import 'trigger_provider.dart';

/// Ensures the app data directory and all configuration files exist on disk
/// before the UI renders. Missing files are created with sensible defaults.
/// Also loads persisted settings from `settings.json`.
final appInitProvider = FutureProvider<void>((ref) async {
  try {
    final storage = ref.read(storageServiceProvider);
    await storage.ensureDirectories();

    await Future.wait([
      _ensureImmersions(storage),
      _ensureAliases(storage),
      _ensureAreaConfig(storage),
      _ensureAlts(storage),
      storage.ensureFile('Command History.md'),
      _loadSettings(ref, storage),
    ]);
  } catch (e) {
    debugPrint('appInitProvider: $e');
  }
});

Future<void> _ensureImmersions(StorageService storage) async {
  final exists = await storage.fileExists('Immersions.md');
  if (!exists) {
    final md =
        MarkdownConfigParser.serializeImmersions(TriggerRulesNotifier.defaults());
    await storage.writeFile('Immersions.md', md);
  }
}

Future<void> _ensureAliases(StorageService storage) async {
  final exists = await storage.fileExists('Aliases.md');
  if (!exists) {
    final md =
        MarkdownConfigParser.serializeAliases(AliasEngine.defaultAliases());
    await storage.writeFile('Aliases.md', md);
  }
}

Future<void> _ensureAreaConfig(StorageService storage) async {
  final exists = await storage.fileExists('Area Configuration.md');
  if (!exists) {
    final md = MarkdownConfigParser.serializeUnifiedAreaConfig(
        UnifiedAreaConfig());
    await storage.writeFile('Area Configuration.md', md);
  }
}

Future<void> _ensureAlts(StorageService storage) async {
  final exists = await storage.fileExists('alts.json');
  if (!exists) {
    await storage.writeFile('alts.json', '[]');
  }
}

/// Loads persisted settings from `settings.json` if it exists.
Future<void> _loadSettings(Ref ref, StorageService storage) async {
  try {
    final contents = await storage.readFile('settings.json');
    if (contents.trim().isNotEmpty) {
      final json = jsonDecode(contents) as Map<String, dynamic>;
      ref.read(settingsProvider.notifier).loadFromJson(json);
    }
  } catch (e) {
    debugPrint('_loadSettings: $e');
  }
}
