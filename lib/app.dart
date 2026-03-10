import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/home_screen.dart';

/// The root application widget.
class AncientAnguishApp extends ConsumerWidget {
  const AncientAnguishApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final theme = switch (settings.themeMode) {
      'classic' => AppTheme.classicDark(),
      'highContrast' => AppTheme.highContrast(),
      _ => AppTheme.rpgDark(),
    };

    return MaterialApp(
      title: 'Ancient Anguish',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
