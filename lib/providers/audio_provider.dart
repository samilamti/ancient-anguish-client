import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/battle_state.dart';
import '../models/game_state.dart';
import '../services/area/area_detector.dart';
import '../services/audio/area_audio_manager.dart';
import '../services/audio/audio_service.dart';
import 'battle_provider.dart';
import 'coord_area_config_provider.dart';
import 'game_state_provider.dart';

/// Provides the [AudioService] singleton.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provides the [AreaAudioManager] singleton.
///
/// Rebuilds when the [AreaDetector] finishes loading area definitions.
final areaAudioManagerProvider = Provider<AreaAudioManager>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final areaDetector =
      ref.watch(areaDetectorProvider).value ?? AreaDetector();
  final manager = AreaAudioManager(
    audioService: audioService,
    areaDetector: areaDetector,
  );

  // Pre-load audio track map from Area Configuration.md.
  final config = ref.read(coordAreaConfigProvider);
  for (final entry in config.entries) {
    if (entry.audioPath != null) {
      manager.setTrackForArea(entry.areaName, entry.audioPath!);
    }
  }
  // Load area-only audio mappings (for text-detected areas like Inns).
  for (final MapEntry(:key, :value) in config.areaAudioMap.entries) {
    manager.setTrackForArea(key, value);
  }

  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Sentinel to distinguish "not provided" from "explicitly null" in copyWith.
const _absent = _Absent();

class _Absent {
  const _Absent();
}

/// Audio UI state (for widgets to react to).
class AudioUiState {
  final bool isPlaying;
  final bool isMuted;
  final double masterVolume;
  final String? currentArea;
  final String? currentTrackPath;
  final bool audioEnabled;
  final bool isBattleAudioActive;
  final List<String> battleThemes;

  const AudioUiState({
    this.isPlaying = false,
    this.isMuted = false,
    this.masterVolume = 0.7,
    this.currentArea,
    this.currentTrackPath,
    this.audioEnabled = true,
    this.isBattleAudioActive = false,
    this.battleThemes = const [],
  });

  AudioUiState copyWith({
    bool? isPlaying,
    bool? isMuted,
    double? masterVolume,
    Object? currentArea = _absent,
    Object? currentTrackPath = _absent,
    bool? audioEnabled,
    bool? isBattleAudioActive,
    List<String>? battleThemes,
  }) {
    return AudioUiState(
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      masterVolume: masterVolume ?? this.masterVolume,
      currentArea: identical(currentArea, _absent)
          ? this.currentArea
          : currentArea as String?,
      currentTrackPath: identical(currentTrackPath, _absent)
          ? this.currentTrackPath
          : currentTrackPath as String?,
      audioEnabled: audioEnabled ?? this.audioEnabled,
      isBattleAudioActive: isBattleAudioActive ?? this.isBattleAudioActive,
      battleThemes: battleThemes ?? this.battleThemes,
    );
  }
}

/// Provides the audio UI state, reacting to game state area changes.
final audioUiStateProvider =
    NotifierProvider<AudioUiNotifier, AudioUiState>(AudioUiNotifier.new);

/// Manages the audio UI state and delegates to [AreaAudioManager].
class AudioUiNotifier extends Notifier<AudioUiState> {
  bool _loadingAudio = false;
  bool _toggling = false;

  // Pending operations queued while _loadingAudio is true.
  // Only the latest of each type is kept (rapid events → last one wins).
  _PendingConfigAudio? _pendingConfigAudio;
  String? _pendingAreaChange;
  bool? _pendingBattleChange;
  bool _pendingFadeOut = false;

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

    // Listen for battle state transitions to trigger battle audio.
    ref.listen<BattleState>(battleStateProvider, (previous, next) {
      final wasInBattle = previous?.inBattle ?? false;
      if (wasInBattle != next.inBattle) {
        _onBattleStateChanged(next.inBattle);
      }
    });

    return const AudioUiState();
  }

  /// Drains the highest-priority pending operation after the current one
  /// completes. Battle takes priority over area/config audio.
  void _drainPending() {
    if (_pendingBattleChange != null) {
      final inBattle = _pendingBattleChange!;
      _pendingBattleChange = null;
      _pendingConfigAudio = null;
      _pendingAreaChange = null;
      _pendingFadeOut = false;
      _onBattleStateChanged(inBattle);
      return;
    }
    if (_pendingConfigAudio != null) {
      final pending = _pendingConfigAudio!;
      _pendingConfigAudio = null;
      _pendingAreaChange = null;
      _pendingFadeOut = false;
      _playConfigAudio(pending.audioPath, pending.areaName);
      return;
    }
    if (_pendingAreaChange != null) {
      final area = _pendingAreaChange!;
      _pendingAreaChange = null;
      _pendingFadeOut = false;
      onAreaChanged(area);
      return;
    }
    if (_pendingFadeOut) {
      _pendingFadeOut = false;
      _fadeOutIfPlaying();
    }
  }

  /// Fades out current audio if something is playing.
  Future<void> _fadeOutIfPlaying() async {
    if (_toggling) return;
    if (_loadingAudio) {
      _pendingFadeOut = true;
      return;
    }
    _loadingAudio = true;
    try {
      if (ref.read(areaAudioManagerProvider).inBattle) return;
      final audioService = ref.read(audioServiceProvider);
      if (audioService.isPlaying) {
        await audioService.stop();
        state = state.copyWith(isPlaying: false, currentTrackPath: null);
      }
    } catch (e) {
      debugPrint('AudioUiNotifier._fadeOutIfPlaying error: $e');
    } finally {
      _loadingAudio = false;
      _drainPending();
    }
  }

  /// Plays audio from a coordinate config entry.
  Future<void> _playConfigAudio(String audioPath, String areaName) async {
    if (_toggling) return;
    if (_loadingAudio) {
      _pendingConfigAudio = _PendingConfigAudio(audioPath, areaName);
      return;
    }
    if (ref.read(areaAudioManagerProvider).inBattle) return;
    _loadingAudio = true;
    try {
      if (!await File(audioPath).exists()) return;
      final audioService = ref.read(audioServiceProvider);
      if (audioPath != audioService.currentTrackPath) {
        await audioService.play(audioPath);
      }
      state = state.copyWith(
        currentArea: areaName,
        isPlaying: audioService.isPlaying,
        currentTrackPath: audioPath,
      );
    } catch (e) {
      debugPrint('AudioUiNotifier._playConfigAudio error: $e');
    } finally {
      _loadingAudio = false;
      _drainPending();
    }
  }

  /// Called when the game state detects a new area.
  Future<void> onAreaChanged(String newArea) async {
    if (_toggling) return;
    if (_loadingAudio) {
      _pendingAreaChange = newArea;
      return;
    }
    _loadingAudio = true;
    try {
      final manager = ref.read(areaAudioManagerProvider);
      await manager.onAreaChanged(newArea);

      state = state.copyWith(
        currentArea: newArea,
        isPlaying: manager.audioService.isPlaying,
        currentTrackPath: manager.audioService.currentTrackPath,
      );
    } catch (e) {
      debugPrint('AudioUiNotifier.onAreaChanged error: $e');
    } finally {
      _loadingAudio = false;
      _drainPending();
    }
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
    if (_toggling) return;
    _toggling = true;
    try {
      final manager = ref.read(areaAudioManagerProvider);
      final newEnabled = !state.audioEnabled;
      await manager.setEnabled(newEnabled);
      state = state.copyWith(
        audioEnabled: newEnabled,
        isPlaying: newEnabled ? state.isPlaying : false,
        currentTrackPath: newEnabled ? state.currentTrackPath : null,
      );
    } catch (e) {
      debugPrint('AudioUiNotifier.toggleAudioEnabled error: $e');
    } finally {
      _toggling = false;
    }
  }

  /// Sets a user track mapping for an area.
  ///
  /// If the player is currently in [areaName], re-triggers audio so the new
  /// track plays immediately.
  void setTrackForArea(String areaName, String filePath) {
    final manager = ref.read(areaAudioManagerProvider);
    manager.setTrackForArea(areaName, filePath);
    _refreshIfCurrentArea(areaName, manager);
  }

  /// Removes a user track mapping.
  ///
  /// If the player is currently in [areaName], re-triggers audio so the
  /// removal takes effect immediately.
  void removeTrackForArea(String areaName) {
    final manager = ref.read(areaAudioManagerProvider);
    manager.removeTrackForArea(areaName);
    _refreshIfCurrentArea(areaName, manager);
  }

  /// If [areaName] matches the area currently playing, reset the manager's
  /// tracking so that [onAreaChanged] will re-evaluate the track.
  void _refreshIfCurrentArea(String areaName, AreaAudioManager manager) {
    if (manager.currentPlayingArea == areaName) {
      manager.clearCurrentArea();
      onAreaChanged(areaName);
    }
  }

  /// Stops all audio.
  Future<void> stop() async {
    try {
      final manager = ref.read(areaAudioManagerProvider);
      await manager.reset();
    } catch (e) {
      debugPrint('AudioUiNotifier.stop error: $e');
    }
    state = state.copyWith(
      isPlaying: false,
      currentTrackPath: null,
      isBattleAudioActive: false,
    );
  }

  // ── Battle themes ──

  /// Handles battle state transitions.
  Future<void> _onBattleStateChanged(bool inBattle) async {
    if (_toggling) return;
    if (_loadingAudio) {
      _pendingBattleChange = inBattle;
      return;
    }
    _loadingAudio = true;
    try {
      final manager = ref.read(areaAudioManagerProvider);
      await manager.onBattleStateChanged(inBattle);

      state = state.copyWith(
        isBattleAudioActive: inBattle && manager.battleThemes.isNotEmpty,
        isPlaying: manager.audioService.isPlaying,
        currentTrackPath: manager.audioService.currentTrackPath,
      );
    } catch (e) {
      debugPrint('AudioUiNotifier._onBattleStateChanged error: $e');
    } finally {
      _loadingAudio = false;
      _drainPending();
    }
  }

  /// Adds a battle theme MP3 path.
  void addBattleTheme(String filePath) {
    final manager = ref.read(areaAudioManagerProvider);
    manager.addBattleTheme(filePath);
    state = state.copyWith(battleThemes: List.from(manager.battleThemes));
  }

  /// Removes a battle theme at [index].
  void removeBattleThemeAt(int index) {
    final manager = ref.read(areaAudioManagerProvider);
    manager.removeBattleThemeAt(index);
    state = state.copyWith(battleThemes: List.from(manager.battleThemes));
  }

  /// Reorders battle themes (drag-and-drop).
  void reorderBattleThemes(int oldIndex, int newIndex) {
    final manager = ref.read(areaAudioManagerProvider);
    manager.reorderBattleThemes(oldIndex, newIndex);
    state = state.copyWith(battleThemes: List.from(manager.battleThemes));
  }
}

/// Holds a pending coordinate-config audio request.
class _PendingConfigAudio {
  final String audioPath;
  final String areaName;
  const _PendingConfigAudio(this.audioPath, this.areaName);
}
