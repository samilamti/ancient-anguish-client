import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/connection_info.dart';
import '../../providers/audio_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/audio/audio_controls.dart';
import '../widgets/mobile/d_pad.dart';
import '../widgets/mobile/quick_commands.dart';
import '../widgets/status/coordinate_display.dart';
import '../widgets/status/status_bar.dart';
import '../widgets/terminal/input_bar.dart';
import '../widgets/terminal/terminal_view.dart';
import 'alias_settings_screen.dart';
import 'audio_settings_screen.dart';
import 'settings_screen.dart';
import 'trigger_settings_screen.dart';

/// The main game screen – contains the terminal output, status bar,
/// audio controls, input bar, and quick commands.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(connectionStatusProvider);
    final settings = ref.watch(settingsProvider);
    final audioState = ref.watch(audioUiStateProvider);
    final isConnected = statusAsync.when(
      data: (status) => status == ConnectionStatus.connected,
      loading: () => false,
      error: (_, _) => false,
    );
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ancient Anguish'),
        titleTextStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 16,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          // Connection indicator.
          _ConnectionIndicator(isConnected: isConnected),

          // Connect / Disconnect button.
          IconButton(
            icon: Icon(isConnected ? Icons.link_off : Icons.link),
            tooltip: isConnected ? 'Disconnect' : 'Connect',
            onPressed: () {
              final service = ref.read(connectionServiceProvider);
              if (isConnected) {
                service.disconnect();
              } else {
                service.connect();
              }
            },
          ),

          // Triggers settings.
          IconButton(
            icon: const Icon(Icons.highlight, size: 20),
            tooltip: 'Triggers & Highlights',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TriggerSettingsScreen(),
                ),
              );
            },
          ),

          // Alias settings.
          IconButton(
            icon: const Icon(Icons.short_text, size: 20),
            tooltip: 'Command Aliases',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AliasSettingsScreen(),
                ),
              );
            },
          ),

          // Audio settings.
          IconButton(
            icon: Icon(
              audioState.audioEnabled ? Icons.music_note : Icons.music_off,
              size: 20,
            ),
            tooltip: 'Audio settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AudioSettingsScreen(),
                ),
              );
            },
          ),

          // Clear terminal.
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear terminal',
            onPressed: () {
              ref.read(terminalBufferProvider.notifier).clear();
            },
          ),

          // Settings.
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Terminal output – takes all available space.
            const Expanded(child: TerminalView()),

            // Status bar (collapsible on mobile, full on desktop).
            if (isConnected) StatusBar(collapsible: isMobile),

            // Coordinate display (visible when connected; auto-hides
            // when no coordinates are available).
            if (isConnected) const CoordinateDisplay(),

            // Audio controls (shown when connected and audio is enabled).
            if (isConnected && audioState.audioEnabled)
              const AudioControls(),

            // Mobile controls (D-Pad or Quick Commands, toggleable).
            if (isMobile && settings.quickCommandsVisible)
              settings.useDPad ? const DPad() : const QuickCommands(),

            // Command input bar.
            const InputBar(),
          ],
        ),
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
