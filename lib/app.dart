import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/app_init_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/home_screen.dart';

/// The root application widget.
class AncientAnguishApp extends ConsumerWidget {
  const AncientAnguishApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(appInitProvider);

    return init.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
      error: (e, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: Text('Init error: $e')),
        ),
      ),
      data: (_) {
        final settings = ref.watch(settingsProvider);

        final theme = switch (settings.themeMode) {
          'classic' => AppTheme.classicDark(),
          'highContrast' => AppTheme.highContrast(),
          'custom' => AppTheme.custom(settings.customThemeColors),
          _ => AppTheme.rpgDark(),
        };

        return MaterialApp(
          title: 'Ancient Anguish',
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: const HomeScreen(),
        );
      },
    );
  }
}
