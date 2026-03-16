import 'storage_service.dart';
import 'web_storage_service.dart';

/// Creates the web storage service (HTTP calls to server file API).
StorageService createStorageService({
  String? baseUrl,
  String Function()? tokenProvider,
}) {
  assert(baseUrl != null, 'baseUrl required for web storage service');
  assert(tokenProvider != null, 'tokenProvider required for web storage service');
  return WebStorageService(
    baseUrl: baseUrl!,
    tokenProvider: tokenProvider!,
  );
}
