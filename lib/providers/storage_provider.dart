import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/web_config.dart';
import '../models/auth_state.dart';
import '../services/storage/create_storage.dart';
import '../services/storage/storage_service.dart';
import 'auth_provider.dart';

/// Provides the [StorageService] singleton.
///
/// Desktop: [LocalStorageService] (dart:io + path_provider).
/// Web: [WebStorageService] (HTTP calls to server file API).
///
/// Platform selection is handled at compile time via conditional imports
/// in `create_storage.dart`.
final storageServiceProvider = Provider<StorageService>((ref) {
  if (kIsWeb) {
    final authState = ref.watch(authProvider);
    if (authState is! AuthAuthenticated) {
      throw StateError('StorageService requires authentication on web');
    }
    return createStorageService(
      baseUrl: WebConfig.serverUrl,
      tokenProvider: () => ref.read(authProvider.notifier).token ?? '',
    );
  }
  return createStorageService();
});
