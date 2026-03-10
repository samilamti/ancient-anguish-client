import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/core/theme/app_theme.dart';
import 'package:ancient_anguish_client/core/theme/terminal_colors.dart';

void main() {
  group('AppTheme', () {
    test('rpgDark scaffold background matches defaultBackground', () {
      final theme = AppTheme.rpgDark();
      expect(theme.scaffoldBackgroundColor, TerminalColors.defaultBackground);
    });

    test('rpgDark primary color is gold', () {
      final theme = AppTheme.rpgDark();
      expect(theme.colorScheme.primary, const Color(0xFFD4A057));
    });

    test('classicDark scaffold background is black', () {
      final theme = AppTheme.classicDark();
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
    });

    test('classicDark primary is bright green', () {
      final theme = AppTheme.classicDark();
      expect(theme.colorScheme.primary, TerminalColors.brightGreen);
    });

    test('highContrast primary is yellow', () {
      final theme = AppTheme.highContrast();
      expect(theme.colorScheme.primary, const Color(0xFFFFFF00));
    });

    test('highContrast scaffold background is black', () {
      final theme = AppTheme.highContrast();
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
    });

    test('custom uses provided color map values', () {
      final theme = AppTheme.custom({
        'primary': 0xFFFF0000,
        'secondary': 0xFF00FF00,
        'background': 0xFF0000FF,
      });
      expect(theme.colorScheme.primary, const Color(0xFFFF0000));
      expect(theme.colorScheme.secondary, const Color(0xFF00FF00));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0000FF));
    });

    test('custom uses defaults for missing keys', () {
      final theme = AppTheme.custom({'primary': 0xFFFF0000});
      // secondary should default to saddleBrown
      expect(theme.colorScheme.secondary, const Color(0xFF8B4513));
    });

    test('custom handles empty map', () {
      final theme = AppTheme.custom({});
      // Should use all defaults — primary defaults to gold
      expect(theme.colorScheme.primary, const Color(0xFFD4A057));
    });
  });
}
