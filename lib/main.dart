import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

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
