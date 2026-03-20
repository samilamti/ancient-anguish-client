import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/logging/log_service.dart';
import 'storage_provider.dart';

/// Application settings state.
class AppSettings {
  final double fontSize;
  final String fontFamily;
  final String themeMode; // 'rpg', 'classic', 'highContrast'
  final String? customPromptPattern;
  final bool loggingEnabled;
  final bool quickCommandsVisible;
  final bool useDPad; // true = compass D-Pad, false = quick command buttons
  final Map<String, int> customThemeColors;
  final bool socialWindowsEnabled; // desktop-only floating chat/tell panels
  final bool gagSocialFromTerminal; // hide social messages from main terminal
  final bool emojiParsingEnabled; // replace text emoticons with emoji
  final int inputWrapWidth; // 0 = disabled, otherwise wrap input at N chars
  final bool blockModeEnabled; // group output into interactive blocks

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
    this.themeMode = 'rpg',
    this.customPromptPattern,
    this.loggingEnabled = false,
    this.quickCommandsVisible = true,
    this.useDPad = true,
    this.customThemeColors = defaultCustomColors,
    this.socialWindowsEnabled = true,
    this.gagSocialFromTerminal = true,
    this.emojiParsingEnabled = true,
    this.inputWrapWidth = 0,
    this.blockModeEnabled = false,
  });

  AppSettings copyWith({
    double? fontSize,
    String? fontFamily,
    String? themeMode,
    String? customPromptPattern,
    bool? loggingEnabled,
    bool? quickCommandsVisible,
    bool? useDPad,
    Map<String, int>? customThemeColors,
    bool? socialWindowsEnabled,
    bool? gagSocialFromTerminal,
    bool? emojiParsingEnabled,
    int? inputWrapWidth,
    bool? blockModeEnabled,
  }) {
    return AppSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
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
      inputWrapWidth: inputWrapWidth ?? this.inputWrapWidth,
      blockModeEnabled: blockModeEnabled ?? this.blockModeEnabled,
    );
  }

  /// Serializes settings to JSON.
  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'themeMode': themeMode,
        if (customPromptPattern != null)
          'customPromptPattern': customPromptPattern,
        'loggingEnabled': loggingEnabled,
        'quickCommandsVisible': quickCommandsVisible,
        'useDPad': useDPad,
        'customThemeColors': customThemeColors,
        'socialWindowsEnabled': socialWindowsEnabled,
        'gagSocialFromTerminal': gagSocialFromTerminal,
        'emojiParsingEnabled': emojiParsingEnabled,
        'inputWrapWidth': inputWrapWidth,
        'blockModeEnabled': blockModeEnabled,
      };

  /// Deserializes settings from JSON, with defaults for missing fields.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
      fontFamily: json['fontFamily'] as String? ?? 'JetBrainsMono',
      themeMode: json['themeMode'] as String? ?? 'rpg',
      customPromptPattern: json['customPromptPattern'] as String?,
      loggingEnabled: json['loggingEnabled'] as bool? ?? false,
      quickCommandsVisible: json['quickCommandsVisible'] as bool? ?? true,
      useDPad: json['useDPad'] as bool? ?? true,
      customThemeColors: json['customThemeColors'] != null
          ? Map<String, int>.from(json['customThemeColors'] as Map)
          : defaultCustomColors,
      socialWindowsEnabled: json['socialWindowsEnabled'] as bool? ?? true,
      gagSocialFromTerminal: json['gagSocialFromTerminal'] as bool? ?? true,
      emojiParsingEnabled: json['emojiParsingEnabled'] as bool? ?? true,
      inputWrapWidth: json['inputWrapWidth'] as int? ?? 0,
      blockModeEnabled: json['blockModeEnabled'] as bool? ?? false,
    );
  }
}

/// Provides application settings.
final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _fileName = 'settings.json';

  @override
  AppSettings build() => const AppSettings();

  /// Loads settings from storage. Called by [appInitProvider] at startup.
  void loadFromJson(Map<String, dynamic> json) {
    state = AppSettings.fromJson(json);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size.clamp(8.0, 32.0));
    _saveSettings();
  }

  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
    _saveSettings();
  }

  void setCustomPromptPattern(String? pattern) {
    state = state.copyWith(customPromptPattern: pattern);
    _saveSettings();
  }

  void toggleQuickCommands() {
    state = state.copyWith(quickCommandsVisible: !state.quickCommandsVisible);
    _saveSettings();
  }

  void toggleDPad() {
    state = state.copyWith(useDPad: !state.useDPad);
    _saveSettings();
  }

  void setCustomThemeColor(String key, int colorValue) {
    final updated = Map<String, int>.from(state.customThemeColors);
    updated[key] = colorValue;
    state = state.copyWith(customThemeColors: updated);
    _saveSettings();
  }

  void toggleSocialWindows() {
    state = state.copyWith(socialWindowsEnabled: !state.socialWindowsEnabled);
    _saveSettings();
  }

  void toggleGagSocial() {
    state =
        state.copyWith(gagSocialFromTerminal: !state.gagSocialFromTerminal);
    _saveSettings();
  }

  void setInputWrapWidth(int width) {
    state = state.copyWith(inputWrapWidth: width.clamp(0, 200));
    _saveSettings();
  }

  void toggleEmojiParsing() {
    state = state.copyWith(emojiParsingEnabled: !state.emojiParsingEnabled);
    _saveSettings();
  }

  void toggleBlockMode() {
    state = state.copyWith(blockModeEnabled: !state.blockModeEnabled);
    _saveSettings();
  }

  Future<void> toggleLogging() async {
    final logService = ref.read(logServiceProvider);
    if (state.loggingEnabled) {
      await logService.stopLogging();
    } else {
      await logService.startLogging(ref.read(storageServiceProvider));
    }
    state = state.copyWith(loggingEnabled: !state.loggingEnabled);
    _saveSettings();
  }

  /// Persists current settings to `settings.json` (fire-and-forget).
  void _saveSettings() {
    _saveSettingsAsync();
  }

  Future<void> _saveSettingsAsync() async {
    try {
      final storage = ref.read(storageServiceProvider);
      final json = jsonEncode(state.toJson());
      await storage.writeFile(_fileName, json);
    } catch (e) {
      debugPrint('SettingsNotifier._saveSettings: $e');
    }
  }
}

/// Provides the [LogService] singleton.
final logServiceProvider = Provider<LogService>((ref) {
  final service = LogService();
  ref.onDispose(() => service.dispose());
  return service;
});
