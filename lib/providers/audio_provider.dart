import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../services/audio/area_audio_manager.dart';
import '../services/audio/audio_service.dart';
import 'coord_area_config_provider.dart';
import 'game_state_provider.dart';

/// Provides the [AudioService] singleton.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provides the [AreaAudioManager] singleton.
final areaAudioManagerProvider = Provider<AreaAudioManager>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final areaDetector = ref.watch(areaDetectorProvider);
  final manager = AreaAudioManager(
    audioService: audioService,
    areaDetector: areaDetector,
  );
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Audio UI state (for widgets to react to).
class AudioUiState {
  final bool isPlaying;
  final bool isMuted;
  final double masterVolume;
  final String? currentArea;
  final String? currentTrackPath;
  final bool audioEnabled;

  const AudioUiState({
    this.isPlaying = false,
    this.isMuted = false,
    this.masterVolume = 0.7,
    this.currentArea,
    this.currentTrackPath,
    this.audioEnabled = true,
  });

  AudioUiState copyWith({
    bool? isPlaying,
    bool? isMuted,
    double? masterVolume,
    String? currentArea,
    String? currentTrackPath,
    bool? audioEnabled,
  }) {
    return AudioUiState(
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      masterVolume: masterVolume ?? this.masterVolume,
      currentArea: currentArea ?? this.currentArea,
      currentTrackPath: currentTrackPath ?? this.currentTrackPath,
      audioEnabled: audioEnabled ?? this.audioEnabled,
    );
  }
}

/// Provides the audio UI state, reacting to game state area changes.
final audioUiStateProvider =
    NotifierProvider<AudioUiNotifier, AudioUiState>(AudioUiNotifier.new);

/// Manages the audio UI state and delegates to [AreaAudioManager].
class AudioUiNotifier extends Notifier<AudioUiState> {
  bool _loadingAudio = false;

  @override
  AudioUiState build() {
    // Listen for game state changes to trigger area audio.
    ref.listen<GameState>(gameStateProvider, (previous, next) {
      // Check coordinate config for audio path (highest priority).
      // Only trigger when coordinates actually change to avoid race conditions.
      if (next.hasCoordinates &&
          (previous?.x != next.x || previous?.y != next.y)) {
        final entry =
            ref.read(coordAreaConfigProvider).lookup(next.x!, next.y!);
        if (entry?.audioPath != null) {
          _playConfigAudio(entry!.audioPath!, entry.areaName);
          return;
        }
        // Coordinates changed but no audio for new position — fade out.
        _fadeOutIfPlaying();
        return;
      }

      // Fall back to area-based audio.
      if (next.currentArea != null &&
          next.currentArea != previous?.currentArea) {
        onAreaChanged(next.currentArea!);
      }
    });

    return const AudioUiState();
  }

  /// Fades out current audio if something is playing.
  Future<void> _fadeOutIfPlaying() async {
    final audioService = ref.read(audioServiceProvider);
    if (audioService.isPlaying) {
      await audioService.fadeOut();
      state = state.copyWith(isPlaying: false, currentTrackPath: null);
    }
  }

  /// Plays audio from a coordinate config entry.
  Future<void> _playConfigAudio(String audioPath, String areaName) async {
    if (_loadingAudio) return;
    _loadingAudio = true;
    try {
      final audioService = ref.read(audioServiceProvider);
      if (audioPath != audioService.currentTrackPath) {
        await audioService.crossfadeTo(audioPath);
      }
      state = state.copyWith(
        currentArea: areaName,
        isPlaying: audioService.isPlaying,
        currentTrackPath: audioPath,
      );
    } finally {
      _loadingAudio = false;
    }
  }

  /// Called when the game state detects a new area.
  Future<void> onAreaChanged(String newArea) async {
    final manager = ref.read(areaAudioManagerProvider);
    await manager.onAreaChanged(newArea);

    state = state.copyWith(
      currentArea: newArea,
      isPlaying: manager.audioService.isPlaying,
      currentTrackPath: manager.audioService.currentTrackPath,
    );
  }

  /// Sets master volume.
  void setVolume(double volume) {
    final audioService = ref.read(audioServiceProvider);
    audioService.setMasterVolume(volume);
    state = state.copyWith(masterVolume: volume);
  }

  /// Toggles mute.
  void toggleMute() {
    final audioService = ref.read(audioServiceProvider);
    audioService.toggleMute();
    state = state.copyWith(isMuted: audioService.isMuted);
  }

  /// Toggles area audio on/off.
  Future<void> toggleAudioEnabled() async {
    final manager = ref.read(areaAudioManagerProvider);
    final newEnabled = !state.audioEnabled;
    await manager.setEnabled(newEnabled);
    state = state.copyWith(
      audioEnabled: newEnabled,
      isPlaying: newEnabled ? state.isPlaying : false,
    );
  }

  /// Sets a user track mapping for an area.
  void setTrackForArea(String areaName, String filePath) {
    final manager = ref.read(areaAudioManagerProvider);
    manager.setTrackForArea(areaName, filePath);
  }

  /// Removes a user track mapping.
  void removeTrackForArea(String areaName) {
    final manager = ref.read(areaAudioManagerProvider);
    manager.removeTrackForArea(areaName);
  }

  /// Stops all audio.
  Future<void> stop() async {
    final manager = ref.read(areaAudioManagerProvider);
    await manager.reset();
    state = state.copyWith(isPlaying: false, currentTrackPath: null);
  }
}
