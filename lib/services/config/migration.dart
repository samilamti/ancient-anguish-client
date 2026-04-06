// Platform-conditional legacy CWD migration.
export 'migration_native.dart'
    if (dart.library.js_interop) 'migration_web.dart';
