import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/logging/log_service.dart';

/// Application settings state.
class AppSettings {
  final double fontSize;
  final String fontFamily;
  final int scrollbackLines;
  final String themeMode; // 'rpg', 'classic', 'highContrast'
  final String? customPromptPattern;
  final bool loggingEnabled;
  final bool quickCommandsVisible;
  final bool useDPad; // true = compass D-Pad, false = quick command buttons
  final Map<String, int> customThemeColors;
  final bool socialWindowsEnabled; // desktop-only floating chat/tell panels
  final bool gagSocialFromTerminal; // hide social messages from main terminal
  final bool emojiParsingEnabled; // replace text emoticons with emoji

  static const Map<String, int> defaultCustomColors = {
    'primary': 0xFFD4A057,
    'secondary': 0xFF8B4513,
    'surface': 0xFF2A1810,
    'onSurface': 0xFFE8D5B7,
    'background': 0xFF1A1A2E,
  };

  const AppSettings({
    this.fontSize = 14.0,
    this.fontFamily = 'JetBrainsMono',
    this.scrollbackLines = 10000,
    this.themeMode = 'rpg',
    this.customPromptPattern,
    this.loggingEnabled = false,
    this.quickCommandsVisible = true,
    this.useDPad = true,
    this.customThemeColors = defaultCustomColors,
    this.socialWindowsEnabled = true,
    this.gagSocialFromTerminal = true,
    this.emojiParsingEnabled = true,
  });

  AppSettings copyWith({
    double? fontSize,
    String? fontFamily,
    int? scrollbackLines,
    String? themeMode,
    String? customPromptPattern,
    bool? loggingEnabled,
    bool? quickCommandsVisible,
    bool? useDPad,
    Map<String, int>? customThemeColors,
    bool? socialWindowsEnabled,
    bool? gagSocialFromTerminal,
    bool? emojiParsingEnabled,
  }) {
    return AppSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      scrollbackLines: scrollbackLines ?? this.scrollbackLines,
      themeMode: themeMode ?? this.themeMode,
      customPromptPattern: customPromptPattern ?? this.customPromptPattern,
      loggingEnabled: loggingEnabled ?? this.loggingEnabled,
      quickCommandsVisible: quickCommandsVisible ?? this.quickCommandsVisible,
      useDPad: useDPad ?? this.useDPad,
      customThemeColors: customThemeColors ?? this.customThemeColors,
      socialWindowsEnabled:
          socialWindowsEnabled ?? this.socialWindowsEnabled,
      gagSocialFromTerminal:
          gagSocialFromTerminal ?? this.gagSocialFromTerminal,
      emojiParsingEnabled:
          emojiParsingEnabled ?? this.emojiParsingEnabled,
    );
  }
}

/// Provides application settings.
final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size.clamp(8.0, 32.0));
  }

  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setScrollbackLines(int lines) {
    state = state.copyWith(scrollbackLines: lines.clamp(1000, 100000));
  }

  void setCustomPromptPattern(String? pattern) {
    state = state.copyWith(customPromptPattern: pattern);
  }

  void toggleQuickCommands() {
    state = state.copyWith(quickCommandsVisible: !state.quickCommandsVisible);
  }

  void toggleDPad() {
    state = state.copyWith(useDPad: !state.useDPad);
  }

  void setCustomThemeColor(String key, int colorValue) {
    final updated = Map<String, int>.from(state.customThemeColors);
    updated[key] = colorValue;
    state = state.copyWith(customThemeColors: updated);
  }

  void toggleSocialWindows() {
    state = state.copyWith(socialWindowsEnabled: !state.socialWindowsEnabled);
  }

  void toggleGagSocial() {
    state =
        state.copyWith(gagSocialFromTerminal: !state.gagSocialFromTerminal);
  }

  void toggleEmojiParsing() {
    state = state.copyWith(emojiParsingEnabled: !state.emojiParsingEnabled);
  }

  Future<void> toggleLogging() async {
    final logService = ref.read(logServiceProvider);
    if (state.loggingEnabled) {
      await logService.stopLogging();
    } else {
      await logService.startLogging();
    }
    state = state.copyWith(loggingEnabled: !state.loggingEnabled);
  }
}

/// Provides the [LogService] singleton.
final logServiceProvider = Provider<LogService>((ref) {
  final service = LogService();
  ref.onDispose(() => service.dispose());
  return service;
});
