import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/services/logging/log_service.dart';

void main() {
  late ProviderContainer container;
  late SettingsNotifier notifier;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        // Override logServiceProvider to avoid file I/O.
        logServiceProvider.overrideWithValue(LogService()),
      ],
    );
    notifier = container.read(settingsProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('AppSettings - defaults', () {
    test('has correct default values', () {
      final settings = container.read(settingsProvider);
      expect(settings.fontSize, 14.0);
      expect(settings.fontFamily, 'JetBrainsMono');
      expect(settings.themeMode, 'rpg');
      expect(settings.customPromptPattern, isNull);
      expect(settings.loggingEnabled, isFalse);
      expect(settings.quickCommandsVisible, isTrue);
      expect(settings.useDPad, isTrue);
      expect(settings.customThemeColors, isNotEmpty);
    });
  });

  group('AppSettings - copyWith', () {
    test('preserves unspecified fields', () {
      const settings = AppSettings(fontSize: 16.0, themeMode: 'classic');
      final copied = settings.copyWith(fontSize: 20.0);
      expect(copied.fontSize, 20.0);
      expect(copied.themeMode, 'classic');
      expect(copied.fontFamily, 'JetBrainsMono');
    });

    test('copies all specified fields', () {
      const settings = AppSettings();
      final copied = settings.copyWith(
        fontSize: 18.0,
        fontFamily: 'FiraCode',
        themeMode: 'highContrast',
      );
      expect(copied.fontSize, 18.0);
      expect(copied.fontFamily, 'FiraCode');
      expect(copied.themeMode, 'highContrast');
    });
  });

  group('SettingsNotifier - setFontSize', () {
    test('sets font size within range', () {
      notifier.setFontSize(18.0);
      expect(container.read(settingsProvider).fontSize, 18.0);
    });

    test('clamps font size below 8 to 8', () {
      notifier.setFontSize(4.0);
      expect(container.read(settingsProvider).fontSize, 8.0);
    });

    test('clamps font size above 32 to 32', () {
      notifier.setFontSize(50.0);
      expect(container.read(settingsProvider).fontSize, 32.0);
    });
  });

  group('SettingsNotifier - toggles', () {
    test('toggleQuickCommands flips visibility', () {
      expect(container.read(settingsProvider).quickCommandsVisible, isTrue);
      notifier.toggleQuickCommands();
      expect(container.read(settingsProvider).quickCommandsVisible, isFalse);
      notifier.toggleQuickCommands();
      expect(container.read(settingsProvider).quickCommandsVisible, isTrue);
    });

    test('toggleDPad flips dPad mode', () {
      expect(container.read(settingsProvider).useDPad, isTrue);
      notifier.toggleDPad();
      expect(container.read(settingsProvider).useDPad, isFalse);
    });

    test('setThemeMode updates themeMode', () {
      notifier.setThemeMode('classic');
      expect(container.read(settingsProvider).themeMode, 'classic');
    });
  });

  group('SettingsNotifier - setCustomThemeColor', () {
    test('adds/updates single color without replacing others', () {
      notifier.setCustomThemeColor('primary', 0xFFFF0000);
      final colors = container.read(settingsProvider).customThemeColors;
      expect(colors['primary'], 0xFFFF0000);
      // Other default colors should still be present.
      expect(colors.containsKey('secondary'), isTrue);
      expect(colors.containsKey('surface'), isTrue);
    });
  });
}
