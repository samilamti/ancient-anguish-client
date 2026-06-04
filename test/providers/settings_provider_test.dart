import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/quick_command.dart';
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
      expect(settings.hideKeyboardOnMobile, isTrue);
      expect(settings.quickCommands, QuickCommand.defaults);
    });
  });

  group('AppSettings - JSON migration', () {
    test('fromJson populates quick-command defaults when key is missing', () {
      final settings = AppSettings.fromJson(const {});
      expect(settings.quickCommands, QuickCommand.defaults);
      expect(settings.hideKeyboardOnMobile, isTrue);
    });

    test('fromJson preserves stored quickCommands list', () {
      final json = {
        'quickCommands': [
          {
            'id': 'q1',
            'label': 'Heal',
            'iconName': 'heart',
            'command': 'heal',
            'selectTarget': false,
            'enabled': true,
          }
        ],
        'hideKeyboardOnMobile': false,
      };
      final settings = AppSettings.fromJson(json);
      expect(settings.quickCommands.length, 1);
      expect(settings.quickCommands.first.label, 'Heal');
      expect(settings.hideKeyboardOnMobile, isFalse);
    });

    test('fromJson drops legacy default_look from upgraded installs', () {
      final json = {
        'quickCommands': [
          {
            'id': 'default_look',
            'label': 'Look',
            'iconName': 'eye',
            'command': 'look',
          },
          {
            'id': 'default_kill',
            'label': 'Kill',
            'iconName': 'skull',
            'command': 'kill',
            'selectTarget': true,
          },
          {
            'id': 'q_custom_eye',
            'label': 'Peek',
            'iconName': 'eye',
            'command': 'glance',
          },
        ],
      };
      final settings = AppSettings.fromJson(json);
      final ids = settings.quickCommands.map((c) => c.id).toList();
      expect(ids, ['default_kill', 'q_custom_eye']);
    });
  });

  group('SettingsNotifier - quick command mutations', () {
    test('setQuickCommands replaces the list', () {
      const replacement = [
        QuickCommand(
          id: 'q1',
          label: 'Heal',
          iconName: 'heart',
          command: 'heal',
        ),
      ];
      notifier.setQuickCommands(replacement);
      final stored = container.read(settingsProvider).quickCommands;
      expect(stored.length, 1);
      expect(stored.first.label, 'Heal');
    });

    test('toggleHideKeyboardOnMobile flips the flag', () {
      expect(container.read(settingsProvider).hideKeyboardOnMobile, isTrue);
      notifier.toggleHideKeyboardOnMobile();
      expect(container.read(settingsProvider).hideKeyboardOnMobile, isFalse);
    });
  });

  group('SettingsNotifier - alias pin slots', () {
    test('pin/unpin toggles state and returns the new pin status', () {
      expect(notifier.toggleAliasPin('a1'), isTrue);
      expect(container.read(settingsProvider).pinnedAliasIds, ['a1']);
      expect(notifier.toggleAliasPin('a1'), isFalse);
      expect(container.read(settingsProvider).pinnedAliasIds, isEmpty);
    });

    test('pinning a fourth alias evicts the oldest (FIFO)', () {
      notifier.toggleAliasPin('a1');
      notifier.toggleAliasPin('a2');
      notifier.toggleAliasPin('a3');
      expect(container.read(settingsProvider).pinnedAliasIds,
          ['a1', 'a2', 'a3']);

      notifier.toggleAliasPin('a4');
      expect(container.read(settingsProvider).pinnedAliasIds,
          ['a2', 'a3', 'a4']);
    });
  });

  group('SettingsNotifier - pinned targets', () {
    test('defaults to empty', () {
      expect(container.read(settingsProvider).pinnedTargets, isEmpty);
    });

    test('addPinnedTarget pins to the front, normalized', () {
      notifier.addPinnedTarget('  Balrog  ');
      expect(container.read(settingsProvider).pinnedTargets, ['balrog']);
    });

    test('newest pinned target goes to the top', () {
      notifier.addPinnedTarget('orc');
      notifier.addPinnedTarget('troll');
      expect(container.read(settingsProvider).pinnedTargets, ['troll', 'orc']);
    });

    test('re-pinning an existing target moves it back to the top', () {
      notifier.addPinnedTarget('orc');
      notifier.addPinnedTarget('troll');
      notifier.addPinnedTarget('orc');
      expect(container.read(settingsProvider).pinnedTargets, ['orc', 'troll']);
    });

    test('collapses internal whitespace and lower-cases', () {
      notifier.addPinnedTarget('Ancient   Dragon');
      expect(
          container.read(settingsProvider).pinnedTargets, ['ancient dragon']);
    });

    test('ignores blank input', () {
      notifier.addPinnedTarget('   ');
      expect(container.read(settingsProvider).pinnedTargets, isEmpty);
    });

    test('removePinnedTarget removes the entry', () {
      notifier.addPinnedTarget('orc');
      notifier.addPinnedTarget('troll');
      notifier.removePinnedTarget('orc');
      expect(container.read(settingsProvider).pinnedTargets, ['troll']);
    });

    test('removePinnedTarget is a no-op for unknown targets', () {
      notifier.addPinnedTarget('orc');
      notifier.removePinnedTarget('dragon');
      expect(container.read(settingsProvider).pinnedTargets, ['orc']);
    });

    test('survives a JSON round-trip', () {
      notifier.addPinnedTarget('orc');
      notifier.addPinnedTarget('troll');
      final json = container.read(settingsProvider).toJson();
      final restored = AppSettings.fromJson(json);
      expect(restored.pinnedTargets, ['troll', 'orc']);
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
