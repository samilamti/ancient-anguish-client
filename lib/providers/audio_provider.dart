import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';

import '../models/battle_state.dart';
import '../models/game_state.dart';
import '../services/area/area_detector.dart';
import '../services/audio/area_audio_manager.dart';
import '../services/audio/audio_service.dart';
import 'battle_provider.dart';
import 'game_state_provider.dart';
import 'unified_area_config_provider.dart';

/// Provides the [AudioService] singleton.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provides the [AreaAudioManager] singleton.
///
/// Rebuilds when the [AreaDetector] or unified config finishes loading.
/// Pre-loads user track mappings and battle themes from the unified config.
final areaAudioManagerProvider = Provider<AreaAudioManager>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final areaDetector =
      ref.watch(areaDetectorProvider).value ?? AreaDetector();
  final manager = AreaAudioManager(
    audioService: audioService,
    areaDetector: areaDetector,
  );

  // Pre-load audio tracks and battle themes from unified config.
  final unifiedConfig = ref.watch(unifiedAreaConfigProvider).value;
  if (unifiedConfig != null) {
    manager.loadUserTrackMap(unifiedConfig.userTrackMap);
    manager.loadBattleThemes(unifiedConfig.battleThemes);
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
  String? _pendingTrackAdvance;

  /// Timer for delaying town music start.
  Timer? _townDelayTimer;

  @override
  AudioUiState build() {
    // Register track-finished callback for auto-advancing playlists.
    final audioService = ref.read(audioServiceProvider);
    audioService.onTrackFinished = _onTrackFinished;

    // Listen for game state changes to trigger area audio.
    ref.listen<GameState>(gameStateProvider, (previous, next) {
      // Check coordinate config for audio path (highest priority).
      // Only trigger when coordinates actually change to avoid race conditions.
      if (next.hasCoordinates &&
          (previous?.x != next.x || previous?.y != next.y)) {
        final unifiedConfig = ref.read(unifiedAreaConfigProvider).value;
        final entry = unifiedConfig?.lookupByCoord(next.x!, next.y!);
        final audioPath = entry != null
            ? unifiedConfig?.getMusicForArea(entry.name)
            : null;
        if (audioPath != null) {
          _cancelTownDelay();
          if (_isTownArea(entry!.name)) {
            final delayedPath = audioPath;
            final delayedArea = entry.name;
            _townDelayTimer = Timer(
              const Duration(milliseconds: AudioDefaults.townDelayMs),
              () => _playConfigAudio(delayedPath, delayedArea),
            );
          } else {
            _playConfigAudio(audioPath, entry.name);
          }
          return;
        }
        // Coordinates changed but no audio for new position — fade out.
        _cancelTownDelay();
        _fadeOutIfPlaying();
        return;
      }

      // Fall back to area-based audio.
      if (next.currentArea != null &&
          next.currentArea != previous?.currentArea) {
        _cancelTownDelay();
        if (_isTownArea(next.currentArea!)) {
          final delayedArea = next.currentArea!;
          _townDelayTimer = Timer(
            const Duration(milliseconds: AudioDefaults.townDelayMs),
            () => onAreaChanged(delayedArea),
          );
        } else {
          onAreaChanged(next.currentArea!);
        }
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
      _pendingTrackAdvance = null;
      _pendingFadeOut = false;
      _onBattleStateChanged(inBattle);
      return;
    }
    if (_pendingConfigAudio != null) {
      final pending = _pendingConfigAudio!;
      _pendingConfigAudio = null;
      _pendingAreaChange = null;
      _pendingTrackAdvance = null;
      _pendingFadeOut = false;
      _playConfigAudio(pending.audioPath, pending.areaName);
      return;
    }
    if (_pendingAreaChange != null) {
      final area = _pendingAreaChange!;
      _pendingAreaChange = null;
      _pendingTrackAdvance = null;
      _pendingFadeOut = false;
      onAreaChanged(area);
      return;
    }
    if (_pendingTrackAdvance != null) {
      final area = _pendingTrackAdvance!;
      _pendingTrackAdvance = null;
      _pendingFadeOut = false;
      _playNextTrackForArea(area);
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
        await audioService.fadeOutAndStop();
        state = state.copyWith(isPlaying: false, currentTrackPath: null);
      }
    } catch (e) {
      debugPrint('AudioUiNotifier._fadeOutIfPlaying error: $e');
    } finally {
      _loadingAudio = false;
      _drainPending();
    }
  }

  /// Whether [areaName] has multiple music tracks configured.
  bool _isMultiTrack(String areaName) {
    final unifiedConfig = ref.read(unifiedAreaConfigProvider).value;
    return (unifiedConfig?.getMusicListForArea(areaName).length ?? 0) > 1;
  }

  /// Whether [areaName] is a town (uses area_definitions.json theme field).
  bool _isTownArea(String areaName) {
    final areaDetector =
        ref.read(areaDetectorProvider).value ?? AreaDetector();
    return areaDetector.getAreaConfig(areaName)?.theme == 'town';
  }

  /// Cancels any pending town delay timer.
  void _cancelTownDelay() {
    _townDelayTimer?.cancel();
    _townDelayTimer = null;
  }

  /// Called by [AudioService] when a non-looping track finishes.
  void _onTrackFinished() {
    if (ref.read(areaAudioManagerProvider).inBattle) return;
    final currentArea = state.currentArea;
    if (currentArea == null) return;
    _playNextTrackForArea(currentArea);
  }

  /// Advances the music cycle and plays the next track for [areaName].
  Future<void> _playNextTrackForArea(String areaName) async {
    if (_toggling) return;
    if (_loadingAudio) {
      _pendingTrackAdvance = areaName;
      return;
    }
    _loadingAudio = true;
    try {
      final unifiedConfig = ref.read(unifiedAreaConfigProvider).value;
      if (unifiedConfig == null) return;

      // Advance to next track in the cycle.
      unifiedConfig.advanceMusicCycle(areaName);
      final nextTrack = unifiedConfig.getMusicForArea(areaName);
      if (nextTrack == null || !await File(nextTrack).exists()) return;

      final audioService = ref.read(audioServiceProvider);
      await audioService.play(nextTrack, looping: false);

      // Update AreaAudioManager's track map so battle restore works.
      final manager = ref.read(areaAudioManagerProvider);
      manager.setTrackForArea(areaName, nextTrack);

      state = state.copyWith(
        isPlaying: audioService.isPlaying,
        currentTrackPath: nextTrack,
      );
    } catch (e) {
      debugPrint('AudioUiNotifier._playNextTrackForArea error: $e');
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
      final shouldLoop = !_isMultiTrack(areaName);
      if (audioPath != audioService.currentTrackPath) {
        await audioService.play(audioPath, looping: shouldLoop);
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
      final shouldLoop = !_isMultiTrack(newArea);
      await manager.onAreaChanged(newArea, looping: shouldLoop);

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
    // Persist via unified config.
    ref.read(unifiedAreaConfigProvider).value?.setMusicForArea(
        areaName, filePath);
    _refreshIfCurrentArea(areaName, manager);
  }

  /// Removes a user track mapping.
  ///
  /// If the player is currently in [areaName], re-triggers audio so the
  /// removal takes effect immediately.
  void removeTrackForArea(String areaName) {
    final manager = ref.read(areaAudioManagerProvider);
    manager.removeTrackForArea(areaName);
    // Persist via unified config.
    ref.read(unifiedAreaConfigProvider).value?.removeAllMusicForArea(areaName);
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
    _cancelTownDelay();
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
    _cancelTownDelay();
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
    ref.read(unifiedAreaConfigProvider).value?.addBattleTheme(filePath);
    state = state.copyWith(battleThemes: List.from(manager.battleThemes));
  }

  /// Removes a battle theme at [index].
  void removeBattleThemeAt(int index) {
    final manager = ref.read(areaAudioManagerProvider);
    manager.removeBattleThemeAt(index);
    ref.read(unifiedAreaConfigProvider).value?.removeBattleThemeAt(index);
    state = state.copyWith(battleThemes: List.from(manager.battleThemes));
  }

  /// Reorders battle themes (drag-and-drop).
  void reorderBattleThemes(int oldIndex, int newIndex) {
    final manager = ref.read(areaAudioManagerProvider);
    manager.reorderBattleThemes(oldIndex, newIndex);
    ref.read(unifiedAreaConfigProvider).value?.reorderBattleThemes(
        oldIndex, newIndex);
    state = state.copyWith(battleThemes: List.from(manager.battleThemes));
  }
}

/// Holds a pending coordinate-config audio request.
class _PendingConfigAudio {
  final String audioPath;
  final String areaName;
  const _PendingConfigAudio(this.audioPath, this.areaName);
}
