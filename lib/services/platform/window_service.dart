import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Thin wrapper around native window attention APIs.
///
/// On Windows this flashes the taskbar icon, on macOS it bounces the dock
/// icon, and on Linux it sets the urgency hint. No-op on mobile platforms
/// and in test environments where the channel is unavailable.
class WindowService {
  static const _channel = MethodChannel('com.ancientanguish.client/window');

  /// Requests the OS to draw attention to the application window.
  /// No-op if the window is already focused (guarded on the native side).
  static Future<void> requestAttention() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    try {
      await _channel.invokeMethod('requestAttention');
    } on MissingPluginException {
      // Channel not registered (e.g. test environment).
    }
  }
}
