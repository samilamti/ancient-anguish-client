import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/connection_info.dart';
import '../../providers/audio_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/game_state_provider.dart';
import '../../providers/login_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/social_panel_provider.dart';
import '../widgets/audio/audio_controls.dart';
import '../widgets/login/login_dialog.dart';
import '../widgets/mobile/d_pad.dart';
import '../widgets/mobile/quick_commands.dart';
import '../widgets/social/social_windows_overlay.dart';
import '../widgets/status/status_bar.dart';
import '../widgets/terminal/input_bar.dart';
import '../widgets/terminal/terminal_view.dart';
import 'about_screen.dart';
import 'advanced_customization_screen.dart';
import 'alias_settings_screen.dart';
import 'area_configuration_screen.dart';
import 'trigger_settings_screen.dart';

/// The main game screen – contains the terminal output, status bar,
/// audio controls, input bar, and quick commands.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(connectionStatusProvider);
    final settings = ref.watch(settingsProvider);
    final audioState = ref.watch(audioUiStateProvider);
    final gameState = ref.watch(gameStateProvider);
    final isConnected = statusAsync.when(
      data: (status) => status == ConnectionStatus.connected,
      loading: () => false,
      error: (_, _) => false,
    );
    final isMobile = MediaQuery.of(context).size.width < 768;
    final playerName = gameState.playerName;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _SettingsDrawer(isMobile: isMobile),
      appBar: AppBar(
        title: playerName != null && isConnected
            ? _TitleWithCharName(name: playerName)
            : const Text('Ancient Anguish'),
        titleTextStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 16,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          // Connection indicator (always pinned).
          _ConnectionIndicator(isConnected: isConnected),

          // Overflow toolbar handles the rest.
          _OverflowToolbar(
            isMobile: isMobile,
            items: [
              _ToolbarItem(
                icon: isConnected ? Icons.link_off : Icons.link,
                label: isConnected ? 'Disconnect' : 'Connect',
                onPressed: () {
                  final service = ref.read(connectionServiceProvider);
                  if (isConnected) {
                    service.disconnect();
                  } else {
                    service.connect();
                  }
                },
              ),
              _ToolbarItem(
                icon: Icons.highlight,
                label: 'Immersions',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TriggerSettingsScreen(),
                    ),
                  );
                },
              ),
              _ToolbarItem(
                icon: Icons.short_text,
                label: 'Aliases',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AliasSettingsScreen(),
                    ),
                  );
                },
              ),
              _ToolbarItem(
                icon: Icons.landscape,
                label: 'Areas',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AreaConfigurationScreen(),
                    ),
                  );
                },
              ),
              if (!isMobile && settings.socialWindowsEnabled) ...[
                _ToolbarItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onPressed: () {
                    ref
                        .read(socialPanelProvider.notifier)
                        .toggleChatVisible();
                  },
                  active: ref.watch(socialPanelProvider).chatPanel.visible,
                ),
                _ToolbarItem(
                  icon: Icons.message_outlined,
                  label: 'Tells',
                  onPressed: () {
                    ref
                        .read(socialPanelProvider.notifier)
                        .toggleTellsVisible();
                  },
                  active:
                      ref.watch(socialPanelProvider).tellsPanel.visible,
                ),
              ],
              _ToolbarItem(
                icon: Icons.clear_all,
                label: 'Clear',
                onPressed: () {
                  ref.read(terminalBufferProvider.notifier).clear();
                },
              ),
              _ToolbarItem(
                icon: Icons.info_outline,
                label: 'About',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AboutScreen(),
                    ),
                  );
                },
              ),
            ],
            // Settings is always pinned at the end.
            pinned: _ToolbarItem(
              icon: Icons.settings,
              label: 'Settings',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // HP/SP bars side by side (under the app bar).
                if (isConnected) const VitalsRow(),

                // Coord/map/info bar.
                if (isConnected) const StatusBar(),

                // Terminal output – takes all available space.
                const Expanded(child: TerminalView()),

                // Audio controls (shown when connected and audio is enabled).
                if (isConnected && audioState.audioEnabled)
                  const AudioControls(),

                // Mobile controls: DPad (if enabled) plus the quick-command row.
                // The quick-command row is always rendered when the keyboard is
                // being hidden so its keyboard-toggle button stays reachable.
                if (isMobile) ...[
                  if (settings.useDPad && settings.quickCommandsVisible)
                    const DPad(),
                  if (settings.hideKeyboardOnMobile ||
                      settings.quickCommandsVisible)
                    const QuickCommands(),
                ],

                // Command input bar.
                const InputBar(),
              ],
            ),

            // Social windows overlay (floating/docked panels).
            if (!isMobile) const Positioned.fill(child: SocialWindowsOverlay()),

            // Login dialog overlay.
            if (ref.watch(loginProvider) is LoginPromptDetected) ...[
              const Positioned.fill(
                child: ColoredBox(color: Colors.black54),
              ),
              const Positioned.fill(child: LoginDialog()),
            ],
          ],
        ),
      ),
    );
  }
}

/// Title widget showing "CharName - Ancient Anguish" with a 3D shadow on the name.
class _TitleWithCharName extends StatelessWidget {
  final String name;
  const _TitleWithCharName({required this.name});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: primary,
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 0,
                  color: primary.withAlpha(80),
                ),
                Shadow(
                  offset: const Offset(2, 2),
                  blurRadius: 1,
                  color: primary.withAlpha(40),
                ),
              ],
            ),
          ),
          TextSpan(
            text: ' - Ancient Anguish',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primary.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data describing a single toolbar action.
class _ToolbarItem {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  const _ToolbarItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });
}

/// Toolbar that shows labeled buttons on desktop and overflows excess items
/// into a "More" popup menu. On mobile, all items are icon-only.
class _OverflowToolbar extends StatelessWidget {
  final bool isMobile;
  final List<_ToolbarItem> items;
  final _ToolbarItem pinned;

  /// Estimated width per labeled button on desktop.
  static const double _desktopItemWidth = 100.0;

  /// Width reserved for the pinned button + overflow menu icon.
  static const double _reservedWidth = 140.0;

  const _OverflowToolbar({
    required this.isMobile,
    required this.items,
    required this.pinned,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            IconButton(
              icon: Icon(item.icon, size: 20),
              tooltip: item.label,
              onPressed: item.onPressed,
            ),
          IconButton(
            icon: Icon(pinned.icon, size: 20),
            tooltip: pinned.label,
            onPressed: pinned.onPressed,
          ),
        ],
      );
    }

    // Desktop: use screen width to estimate how many labeled buttons fit.
    // Reserve ~280px for the title area and connection indicator.
    final screenWidth = MediaQuery.of(context).size.width;
    final available = screenWidth - 280 - _reservedWidth;
    final visibleCount =
        (available / _desktopItemWidth).floor().clamp(0, items.length);

    final visible = items.sublist(0, visibleCount);
    final overflowed = items.sublist(visibleCount);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in visible) _buildDesktopButton(context, item),
        if (overflowed.isNotEmpty)
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: 'More',
            onSelected: (index) => overflowed[index].onPressed(),
            itemBuilder: (_) => [
              for (var i = 0; i < overflowed.length; i++)
                PopupMenuItem<int>(
                  value: i,
                  child: Row(
                    children: [
                      Icon(overflowed[i].icon, size: 18),
                      const SizedBox(width: 12),
                      Text(overflowed[i].label),
                    ],
                  ),
                ),
            ],
          ),
        _buildDesktopButton(context, pinned),
      ],
    );
  }

  Widget _buildDesktopButton(BuildContext context, _ToolbarItem item) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = item.active ? primary : null;

    return TextButton.icon(
      icon: Icon(item.icon, size: 20, color: color),
      label: Text(
        item.label,
        style: TextStyle(fontSize: 11, color: color),
      ),
      onPressed: item.onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Small dot indicator showing connection status.
class _ConnectionIndicator extends StatelessWidget {
  final bool isConnected;

  const _ConnectionIndicator({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? Colors.green : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? Colors.green : Colors.red)
                      .withAlpha(100),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slide-in settings panel shown as an end drawer.
class _SettingsDrawer extends ConsumerWidget {
  final bool isMobile;

  const _SettingsDrawer({required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Text(
              'Settings',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // ── Theme ──
            _DrawerSectionHeader(title: 'Theme', icon: Icons.palette),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: settings.themeMode,
              onChanged: (v) => notifier.setThemeMode(v!),
              child: Column(
                children: [
                  for (final entry in {
                    'rpg': 'RPG Fantasy',
                    'classic': 'Classic Dark',
                    'highContrast': 'High Contrast',
                    'custom': 'Custom',
                  }.entries)
                    RadioListTile<String>(
                      title: Text(entry.value,
                          style: const TextStyle(fontSize: 14)),
                      value: entry.key,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),

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
                      _DrawerColorTile(
                        label: entry.value,
                        colorValue: settings.customThemeColors[entry.key] ??
                            AppSettings.defaultCustomColors[entry.key]!,
                        onChanged: (v) =>
                            notifier.setCustomThemeColor(entry.key, v),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // ── Font Size ──
            Row(
              children: [
                const Icon(Icons.text_fields, size: 18),
                const SizedBox(width: 8),
                Text('Font Size', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  '${settings.fontSize.round()}pt',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'JetBrainsMono',
                    color: theme.colorScheme.onSurface.withAlpha(160),
                  ),
                ),
              ],
            ),
            Slider(
              value: settings.fontSize,
              min: 8.0,
              max: 32.0,
              divisions: 24,
              label: '${settings.fontSize.round()}pt',
              onChanged: (v) => notifier.setFontSize(v),
            ),

            const Divider(height: 24),

            // ── Toggles ──
            _DrawerSectionHeader(title: 'Options', icon: Icons.tune),
            const SizedBox(height: 4),

            if (!isMobile) ...[
              _DrawerToggle(
                label: 'Social Windows',
                icon: Icons.chat,
                value: settings.socialWindowsEnabled,
                onChanged: (_) => notifier.toggleSocialWindows(),
              ),
              if (settings.socialWindowsEnabled)
                _DrawerToggle(
                  label: 'Hide Social from Terminal',
                  icon: Icons.visibility_off,
                  value: settings.gagSocialFromTerminal,
                  onChanged: (_) => notifier.toggleGagSocial(),
                ),
            ],

            _DrawerToggle(
              label: 'Emoji Parsing',
              icon: Icons.emoji_emotions,
              value: settings.emojiParsingEnabled,
              onChanged: (_) => notifier.toggleEmojiParsing(),
            ),

            if (!isMobile)
              _DrawerToggle(
                label: 'Block Mode',
                icon: Icons.view_agenda,
                value: settings.blockModeEnabled,
                onChanged: (_) => notifier.toggleBlockMode(),
              ),

            if (isMobile) ...[
              _DrawerToggle(
                label: 'Quick Commands',
                icon: Icons.grid_view,
                value: settings.quickCommandsVisible,
                onChanged: (_) => notifier.toggleQuickCommands(),
              ),
              if (settings.quickCommandsVisible)
                _DrawerToggle(
                  label: 'Use D-Pad',
                  icon: Icons.explore,
                  value: settings.useDPad,
                  onChanged: (_) => notifier.toggleDPad(),
                ),
            ],

            _DrawerToggle(
              label: 'Session Logging',
              icon: Icons.save,
              value: settings.loggingEnabled,
              onChanged: (_) => notifier.toggleLogging(),
            ),

            if (settings.loggingEnabled)
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 4),
                child: Text(
                  ref.read(logServiceProvider).currentLogName ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),

            const Divider(height: 24),

            // ── Input Wrap ──
            Row(
              children: [
                const Icon(Icons.wrap_text, size: 18),
                const SizedBox(width: 8),
                Text('Line Wrap', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  settings.inputWrapWidth == 0
                      ? 'Off'
                      : '${settings.inputWrapWidth}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'JetBrainsMono',
                    color: theme.colorScheme.onSurface.withAlpha(160),
                  ),
                ),
              ],
            ),
            Slider(
              value: settings.inputWrapWidth.toDouble(),
              min: 0,
              max: 200,
              divisions: 200,
              label: settings.inputWrapWidth == 0
                  ? 'Off'
                  : '${settings.inputWrapWidth}',
              onChanged: (v) => notifier.setInputWrapWidth(v.round()),
            ),

            const Divider(height: 24),

            // ── Advanced Customization ──
            ListTile(
              leading: const Icon(Icons.tune, size: 20),
              title: const Text('Advanced Customization'),
              subtitle: const Text('HUD stat visibility'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              dense: true,
              onTap: () {
                Navigator.of(context).pop(); // close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdvancedCustomizationScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _DrawerSectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _DrawerToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DrawerToggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, size: 20),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _DrawerColorTile extends StatelessWidget {
  final String label;
  final int colorValue;
  final ValueChanged<int> onChanged;

  const _DrawerColorTile({
    required this.label,
    required this.colorValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    final hex = colorValue
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color:
                    Theme.of(context).colorScheme.onSurface.withAlpha(60),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              controller: TextEditingController(text: hex),
              style: const TextStyle(
                  fontSize: 12, fontFamily: 'JetBrainsMono'),
              decoration: const InputDecoration(
                prefixText: '#',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              ),
              onSubmitted: (value) {
                final parsed = int.tryParse(
                    'FF${value.replaceAll('#', '')}',
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
