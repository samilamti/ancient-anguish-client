import 'local_storage_service.dart';
import 'storage_service.dart';

/// Creates the desktop storage service (local file I/O).
StorageService createStorageService({
  String? baseUrl,
  String Function()? tokenProvider,
}) {
  return LocalStorageService();
}
