import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/play_mode_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/common/escape_dismiss.dart';

/// Options for keyboard play mode (design/keyboard-play-mode.md).
class PlayModeSettingsScreen extends ConsumerWidget {
  const PlayModeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(playModeProvider.select((m) => m.isOn));
    final overlay =
        ref.watch(settingsProvider.select((s) => s.playModeKeyOverlay));

    return EscapeDismiss(
      child: Scaffold(
        appBar: AppBar(title: const Text('Play Mode')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.sports_esports),
              title: const Text('Play mode'),
              subtitle: const Text(
                  'WASD moves, 1–0 fire the action bar, Enter opens the '
                  'input. Also Ctrl/Cmd+G.'),
              value: on,
              onChanged: (v) =>
                  ref.read(playModeProvider.notifier).setEnabled(v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.keyboard),
              title: const Text('Show pressed keys'),
              subtitle: const Text(
                  'Briefly show the key and the command it sent in the '
                  'middle of the output.'),
              value: overlay,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .setPlayModeKeyOverlay(v),
            ),
          ],
        ),
      ),
    );
  }
}
