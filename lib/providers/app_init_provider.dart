import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/area_config_entry.dart';
import '../services/alias/alias_engine.dart';
import '../services/config/markdown_config_parser.dart';
import 'trigger_provider.dart';

/// Ensures the app data directory and all configuration files exist on disk
/// before the UI renders. Missing files are created with sensible defaults.
final appInitProvider = FutureProvider<void>((ref) async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final basePath = '${docsDir.path}/AncientAnguishClient';
    await Directory(basePath).create(recursive: true);

    await Future.wait([
      _ensureImmersions(basePath),
      _ensureAliases(basePath),
      _ensureAreaConfig(basePath),
      _ensureAlts(basePath),
      _ensureFile('$basePath/Chat History.md'),
      _ensureFile('$basePath/Tell History.md'),
    ]);
  } catch (e) {
    debugPrint('appInitProvider: $e');
  }
});

Future<void> _ensureImmersions(String basePath) async {
  final file = File('$basePath/Immersions.md');
  if (!file.existsSync()) {
    final md =
        MarkdownConfigParser.serializeImmersions(TriggerRulesNotifier.defaults());
    await file.writeAsString(md);
  }
}

Future<void> _ensureAliases(String basePath) async {
  final file = File('$basePath/Aliases.md');
  if (!file.existsSync()) {
    final md =
        MarkdownConfigParser.serializeAliases(AliasEngine.defaultAliases());
    await file.writeAsString(md);
  }
}

Future<void> _ensureAreaConfig(String basePath) async {
  final file = File('$basePath/Area Configuration.md');
  if (!file.existsSync()) {
    final md = MarkdownConfigParser.serializeUnifiedAreaConfig(
        UnifiedAreaConfig());
    await file.writeAsString(md);
  }
}

Future<void> _ensureAlts(String basePath) async {
  final file = File('$basePath/alts.json');
  if (!file.existsSync()) {
    await file.writeAsString('[]');
  }
}

Future<void> _ensureFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    await file.writeAsString('');
  }
}
