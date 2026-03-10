import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/audio_provider.dart';

/// Compact audio control bar showing current track, volume, and mute toggle.
///
/// Displayed below the status bar when audio is active.
class AudioControls extends ConsumerWidget {
  const AudioControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioUiStateProvider);
    final notifier = ref.read(audioUiStateProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(200),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withAlpha(30),
          ),
        ),
      ),
      child: Row(
        children: [
          // Music note icon.
          Icon(
            audioState.isPlaying ? Icons.music_note : Icons.music_off,
            size: 16,
            color: audioState.isPlaying
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withAlpha(80),
          ),
          const SizedBox(width: 8),

          // Now playing info.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  audioState.isPlaying
                      ? _trackName(audioState.currentTrackPath)
                      : 'No audio',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (audioState.currentArea != null)
                  Text(
                    audioState.currentArea!,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      color: theme.colorScheme.primary.withAlpha(140),
                    ),
                  ),
              ],
            ),
          ),

          // Volume slider (compact).
          SizedBox(
            width: 100,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 12,
                ),
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor:
                    theme.colorScheme.primary.withAlpha(40),
                thumbColor: theme.colorScheme.primary,
              ),
              child: Slider(
                value: audioState.masterVolume,
                min: 0.0,
                max: 1.0,
                onChanged: notifier.setVolume,
              ),
            ),
          ),

          // Mute toggle.
          IconButton(
            icon: Icon(
              audioState.isMuted ? Icons.volume_off : Icons.volume_up,
              size: 18,
              color: audioState.isMuted
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface.withAlpha(160),
            ),
            onPressed: notifier.toggleMute,
            tooltip: audioState.isMuted ? 'Unmute' : 'Mute',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),

          // Enable/disable area audio.
          IconButton(
            icon: Icon(
              audioState.audioEnabled
                  ? Icons.spatial_audio_off
                  : Icons.spatial_audio,
              size: 18,
              color: audioState.audioEnabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withAlpha(80),
            ),
            onPressed: notifier.toggleAudioEnabled,
            tooltip: audioState.audioEnabled
                ? 'Disable area audio'
                : 'Enable area audio',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }

  /// Extracts a display name from a file path.
  String _trackName(String? path) {
    if (path == null) return 'Unknown';
    final name = path.split('/').last.split('\\').last;
    // Remove extension.
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }
}
