// Platform-conditional file utilities.
export 'file_utils_native.dart'
    if (dart.library.js_interop) 'file_utils_web.dart';
