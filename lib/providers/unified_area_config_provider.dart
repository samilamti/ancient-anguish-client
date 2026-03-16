import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/config/unified_area_config_manager.dart';
import 'storage_provider.dart';

/// Provides the [UnifiedAreaConfigManager] singleton, loading the unified
/// `Area Configuration.md` from disk on first access.
///
/// Replaces the old `coordAreaConfigProvider`, `areaBackgroundManagerProvider`,
/// and audio config loading from `area-audio.md`.
final unifiedAreaConfigProvider =
    FutureProvider<UnifiedAreaConfigManager>((ref) async {
  final storage = ref.read(storageServiceProvider);
  final manager = UnifiedAreaConfigManager();
  await manager.loadFromDisk(storage);
  return manager;
});
