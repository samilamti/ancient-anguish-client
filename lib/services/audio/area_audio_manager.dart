import 'dart:io';

import 'package:flutter/foundation.dart';

import '../area/area_detector.dart';
import 'audio_service.dart';

/// Manages area-based soundtrack playback.
///
/// Listens for area changes (from [AreaDetector]) and triggers the appropriate
/// audio track via [AudioService]. Handles crossfading between area tracks,
/// silence for unmapped areas, and user-configured track overrides.
class AreaAudioManager {
  final AudioService _audioService;
  final AreaDetector _areaDetector;

  String? _currentPlayingArea;
  bool _enabled = true;

  /// User-configured area-to-file path mappings.
  /// These override the defaults from area_definitions.json.
  final Map<String, String> _userTrackMap = {};

  AreaAudioManager({
    required AudioService audioService,
    required AreaDetector areaDetector,
  })  : _audioService = audioService,
        _areaDetector = areaDetector;

  /// Whether area-based audio is enabled.
  bool get isEnabled => _enabled;

  /// The area currently playing audio for, or null.
  String? get currentPlayingArea => _currentPlayingArea;

  /// The audio service (for direct volume/mute control).
  AudioService get audioService => _audioService;

  /// Enables or disables area-based audio.
  ///
  /// When disabling, awaits the fade-out to prevent concurrent audio
  /// operations if an area change arrives before the fade completes.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) {
      try {
        await _audioService.fadeOut();
      } catch (e) {
        debugPrint('AreaAudioManager.setEnabled fadeOut error: $e');
      }
      _currentPlayingArea = null;
    }
  }

  /// Sets a user-configured MP3 file path for an area.
  void setTrackForArea(String areaName, String filePath) {
    _userTrackMap[areaName] = filePath;
  }

  /// Removes a user-configured track mapping for an area.
  void removeTrackForArea(String areaName) {
    _userTrackMap.remove(areaName);
  }

  /// Returns all user-configured track mappings.
  Map<String, String> get userTrackMap => Map.unmodifiable(_userTrackMap);

  /// Loads user track mappings from a map (e.g., from settings storage).
  void loadUserTrackMap(Map<String, String> map) {
    _userTrackMap.clear();
    _userTrackMap.addAll(map);
  }

  /// Called when the detected area changes. Triggers audio transition.
  ///
  /// This is the main entry point – call this whenever the area detector
  /// reports a new area.
  Future<void> onAreaChanged(String newArea) async {
    if (!_enabled) return;
    if (newArea == _currentPlayingArea) return;

    final trackPath = _resolveTrackPath(newArea);

    if (trackPath == null) {
      // No track for this area – fade out to silence.
      try {
        if (_audioService.isPlaying) {
          await _audioService.fadeOut();
        }
      } catch (e) {
        debugPrint('AreaAudioManager.onAreaChanged fadeOut error: $e');
      }
      _currentPlayingArea = newArea;
      return;
    }

    // Verify the file exists.
    if (!await File(trackPath).exists()) {
      // Track file missing – fade out gracefully.
      try {
        if (_audioService.isPlaying) {
          await _audioService.fadeOut();
        }
      } catch (e) {
        debugPrint('AreaAudioManager.onAreaChanged fadeOut error: $e');
      }
      _currentPlayingArea = newArea;
      return;
    }

    // Get area-specific volume and fade settings.
    final areaConfig = _areaDetector.getAreaConfig(newArea);
    final volume = areaConfig?.audio?.volume ?? 0.7;
    final fadeMs = areaConfig?.audio?.fadeMs ?? 2000;

    // Crossfade to the new track.
    try {
      await _audioService.crossfadeTo(
        trackPath,
        volume: volume,
        fadeInMs: fadeMs,
        fadeOutMs: fadeMs,
      );
    } catch (e) {
      debugPrint('AreaAudioManager.onAreaChanged crossfadeTo error: $e');
    }

    _currentPlayingArea = newArea;
  }

  /// Resolves the track file path for an area.
  ///
  /// Priority: user mapping > area_definitions.json audio config.
  String? _resolveTrackPath(String areaName) {
    // Check user override first.
    if (_userTrackMap.containsKey(areaName)) {
      return _userTrackMap[areaName];
    }

    // Check area config from definitions.
    final config = _areaDetector.getAreaConfig(areaName);
    if (config?.audio != null) {
      // The track field in area_definitions.json is just a filename.
      // The user must have placed the file in the audio cache directory.
      // We'll return the filename and let the caller resolve the full path.
      // For now, check if user has mapped this area.
      return null; // No bundled tracks – user must provide.
    }

    return null;
  }

  /// Stops all audio and resets state.
  Future<void> reset() async {
    try {
      await _audioService.stop();
    } catch (e) {
      debugPrint('AreaAudioManager.reset error: $e');
    }
    _currentPlayingArea = null;
  }

  /// Cleans up manager state. Does NOT dispose the AudioService
  /// since it is a shared singleton owned by [audioServiceProvider].
  Future<void> dispose() async {
    _enabled = false;
    _currentPlayingArea = null;
  }
}
