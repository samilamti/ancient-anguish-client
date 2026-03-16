// Platform-conditional storage service factory.
export 'create_storage_native.dart'
    if (dart.library.js_interop) 'create_storage_web.dart';
