// Platform-conditional app exit.
export 'exit_app_native.dart'
    if (dart.library.js_interop) 'exit_app_web.dart';
