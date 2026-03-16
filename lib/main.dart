import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/platform/exit_app.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // Ensure the Dart VM exits when the native window is closed.
    // Without this, active sockets and FFI resources keep the process alive.
    AppLifecycleListener(onStateChange: (state) {
      if (state == AppLifecycleState.detached) {
        exitApp();
      }
    });

    // Catch Flutter framework errors (build/layout/paint).
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };

    // Catch platform errors routed through PlatformDispatcher.
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformDispatcher error: $error\n$stack');
      return true;
    };

    runApp(
      const ProviderScope(
        child: AncientAnguishApp(),
      ),
    );
  }, (error, stack) {
    // Last resort: catch unhandled async errors that escape
    // individual try-catch blocks.
    debugPrint('Unhandled error: $error\n$stack');
  });
}
