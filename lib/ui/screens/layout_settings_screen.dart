import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../widgets/common/escape_dismiss.dart';
import '../widgets/common/settings_drawer_route.dart';
import 'advanced_customization_screen.dart';

/// What sits around the terminal: social windows, the compass, the mobile
/// command pad and the HUD stats. Opened from the Settings drawer.
class LayoutSettingsScreen extends ConsumerWidget {
  final bool isMobile;

  const LayoutSettingsScreen({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return EscapeDismiss(
      child: Scaffold(
        appBar: AppBar(title: const Text('Layout')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (!isMobile) ...[
              SwitchListTile(
                secondary: const Icon(Icons.chat),
                title: const Text('Social windows'),
                subtitle: const Text(
                    'Chat, tells, party, notes and achievements in their own '
                    'windows. Also the Communications button.'),
                value: settings.socialWindowsEnabled,
                onChanged: (_) => notifier.toggleSocialWindows(),
              ),
              if (settings.socialWindowsEnabled)
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off),
                  title: const Text('Hide social from terminal'),
                  subtitle: const Text(
                      'Show chat and tells only in the social windows.'),
                  value: settings.gagSocialFromTerminal,
                  onChanged: (_) => notifier.toggleGagSocial(),
                ),
              SwitchListTile(
                secondary: const Icon(Icons.explore),
                title: const Text('Navigation compass'),
                subtitle: const Text('Directions to nearby places, top right.'),
                value: settings.compassEnabled,
                onChanged: (_) => notifier.toggleCompass(),
              ),
            ],
            if (isMobile) ...[
              SwitchListTile(
                secondary: const Icon(Icons.grid_view),
                title: const Text('Quick commands'),
                value: settings.quickCommandsVisible,
                onChanged: (_) => notifier.toggleQuickCommands(),
              ),
              if (settings.quickCommandsVisible)
                SwitchListTile(
                  secondary: const Icon(Icons.explore),
                  title: const Text('Use D-Pad'),
                  value: settings.useDPad,
                  onChanged: (_) => notifier.toggleDPad(),
                ),
            ],
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('HUD stats'),
              subtitle: const Text('Which stats the HUD shows'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                const screen = AdvancedCustomizationScreen();
                if (isMobile) {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => screen));
                } else {
                  openSettingsDrawer(context, screen);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
