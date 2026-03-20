import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import 'about_screen.dart';
import 'alias_settings_screen.dart';
import 'area_configuration_screen.dart';
import 'trigger_settings_screen.dart';

/// Settings screen for configuring the client.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Display section ──
          _SectionHeader(title: 'Display', icon: Icons.text_fields),
          const SizedBox(height: 8),

          // Theme selector.
          _SettingsTile(
            title: 'Theme',
            subtitle: _themeLabel(settings.themeMode),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'rpg',
                  label: Text('RPG'),
                  icon: Icon(Icons.castle),
                ),
                ButtonSegment(
                  value: 'classic',
                  label: Text('Classic'),
                  icon: Icon(Icons.terminal),
                ),
                ButtonSegment(
                  value: 'highContrast',
                  label: Text('Hi-Con'),
                  icon: Icon(Icons.contrast),
                ),
                ButtonSegment(
                  value: 'custom',
                  label: Text('Custom'),
                  icon: Icon(Icons.palette),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selected) {
                notifier.setThemeMode(selected.first);
              },
            ),
          ),

          // Custom color editors (shown when Custom theme is selected).
          if (settings.themeMode == 'custom')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  for (final entry in {
                    'primary': 'Primary',
                    'secondary': 'Secondary',
                    'surface': 'Surface',
                    'onSurface': 'On Surface',
                    'background': 'Background',
                  }.entries)
                    _ColorEditorTile(
                      label: entry.value,
                      colorKey: entry.key,
                      colorValue: settings.customThemeColors[entry.key] ??
                          AppSettings.defaultCustomColors[entry.key]!,
                      onChanged: (value) =>
                          notifier.setCustomThemeColor(entry.key, value),
                    ),
                ],
              ),
            ),


          // Font size slider.
          _SettingsTile(
            title: 'Font Size',
            subtitle: '${settings.fontSize.round()}pt',
            child: Slider(
              value: settings.fontSize,
              min: 8.0,
              max: 32.0,
              divisions: 24,
              label: '${settings.fontSize.round()}pt',
              onChanged: (value) => notifier.setFontSize(value),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.landscape),
            title: const Text('Area Configuration'),
            subtitle: const Text('Music, backgrounds, and coordinates per area'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AreaConfigurationScreen(),
                ),
              );
            },
          ),

          const Divider(height: 32),

          // ── Accessibility section ──
          _SectionHeader(title: 'Accessibility', icon: Icons.accessibility),
          const SizedBox(height: 8),

          _SettingsTile(
            title: 'Input Line Wrap',
            subtitle: settings.inputWrapWidth == 0
                ? 'Disabled'
                : '${settings.inputWrapWidth} characters',
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: settings.inputWrapWidth.toDouble(),
                    min: 0,
                    max: 200,
                    divisions: 200,
                    label: settings.inputWrapWidth == 0
                        ? 'Off'
                        : '${settings.inputWrapWidth}',
                    onChanged: (value) =>
                        notifier.setInputWrapWidth(value.round()),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    settings.inputWrapWidth == 0
                        ? 'Off'
                        : '${settings.inputWrapWidth}',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'JetBrainsMono',
                      color: theme.colorScheme.onSurface.withAlpha(180),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          // ── Game section ──
          _SectionHeader(title: 'Game', icon: Icons.gamepad),
          const SizedBox(height: 8),

          // Social windows (desktop only).
          if (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux) ...[
            SwitchListTile(
              title: const Text('Social Windows'),
              subtitle: const Text('Floating Chat and Tell panels'),
              value: settings.socialWindowsEnabled,
              onChanged: (_) => notifier.toggleSocialWindows(),
              secondary: const Icon(Icons.chat),
            ),
            if (settings.socialWindowsEnabled)
              SwitchListTile(
                title: const Text('Hide Social from Terminal'),
                subtitle: const Text(
                  'Only show chat/tells in social windows',
                ),
                value: settings.gagSocialFromTerminal,
                onChanged: (_) => notifier.toggleGagSocial(),
                secondary: const Icon(Icons.visibility_off),
              ),
          ],

          SwitchListTile(
            title: const Text('Emoji Parsing'),
            subtitle: const Text(
              'Replace text emoticons like :) with emoji',
            ),
            value: settings.emojiParsingEnabled,
            onChanged: (_) => notifier.toggleEmojiParsing(),
            secondary: const Icon(Icons.emoji_emotions),
          ),

          // Quick commands toggle (mobile only).
          if (defaultTargetPlatform != TargetPlatform.windows &&
              defaultTargetPlatform != TargetPlatform.macOS) ...[
            SwitchListTile(
              title: const Text('Quick Command Buttons'),
              subtitle: const Text('Show shortcut buttons on mobile'),
              value: settings.quickCommandsVisible,
              onChanged: (_) => notifier.toggleQuickCommands(),
              secondary: const Icon(Icons.grid_view),
            ),

            // D-Pad vs Quick Commands.
            if (settings.quickCommandsVisible)
              SwitchListTile(
                title: const Text('Use D-Pad'),
                subtitle: Text(
                  settings.useDPad
                      ? 'Compass rose with 8 directions'
                      : 'Simple quick command buttons',
                ),
                value: settings.useDPad,
                onChanged: (_) => notifier.toggleDPad(),
                secondary: const Icon(Icons.explore),
              ),
          ],

          const Divider(height: 32),

          // ── Automation section ──
          _SectionHeader(title: 'Automation', icon: Icons.auto_awesome),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.highlight),
            title: const Text('Immersions'),
            subtitle: const Text('Highlights, sounds, and gags on patterns'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TriggerSettingsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.short_text),
            title: const Text('Command Aliases'),
            subtitle: const Text('Expand short keywords into commands'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AliasSettingsScreen(),
                ),
              );
            },
          ),

          const Divider(height: 32),

          // ── Logging section ──
          _SectionHeader(title: 'Logging', icon: Icons.description),
          const SizedBox(height: 8),

          SwitchListTile(
            title: const Text('Session Logging'),
            subtitle: Text(
              settings.loggingEnabled
                  ? 'Logging to file'
                  : 'Disabled',
            ),
            value: settings.loggingEnabled,
            onChanged: (_) => notifier.toggleLogging(),
            secondary: const Icon(Icons.save),
          ),

          if (settings.loggingEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'Log file: ${ref.read(logServiceProvider).currentLogName ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withAlpha(100),
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ),

          const Divider(height: 32),

          // ── About section ──
          _SectionHeader(title: 'About', icon: Icons.info_outline),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Ancient Anguish Client'),
            subtitle: const Text('v0.4.0 — Phase 4\nA cross-platform MUD client for Ancient Anguish'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AboutScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _themeLabel(String mode) {
    return switch (mode) {
      'rpg' => 'RPG Fantasy',
      'classic' => 'Classic Dark',
      'highContrast' => 'High Contrast',
      'custom' => 'Custom',
      _ => mode,
    };
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ColorEditorTile extends StatelessWidget {
  final String label;
  final String colorKey;
  final int colorValue;
  final ValueChanged<int> onChanged;

  const _ColorEditorTile({
    required this.label,
    required this.colorKey,
    required this.colorValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    final hex = colorValue.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(60),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: TextEditingController(text: hex),
              style: const TextStyle(fontSize: 13, fontFamily: 'JetBrainsMono'),
              decoration: const InputDecoration(
                prefixText: '#',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onSubmitted: (value) {
                final parsed = int.tryParse('FF${value.replaceAll('#', '')}',
                    radix: 16);
                if (parsed != null) onChanged(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
