import 'dart:io';

import 'package:flutter/foundation.dart';

import '../area/area_detector.dart';
import 'audio_service.dart';

/// Manages area-based soundtrack playback.
///
/// Listens for area changes (from [AreaDetector]) and triggers the appropriate
/// audio track via [AudioService]. Handles switching between area tracks,
/// silence for unmapped areas, and user-configured track overrides.
class AreaAudioManager {
  final AudioService _audioService;
  final AreaDetector _areaDetector;

  String? _currentPlayingArea;
  bool _enabled = true;

  /// User-configured area-to-file path mappings.
  /// These override the defaults from area_definitions.json.
  final Map<String, String> _userTrackMap = {};

  /// User-configured battle theme MP3 paths, played in sequence.
  final List<String> _battleThemes = [];

  /// Index of the next battle theme to play (advances per battle, wraps).
  int _battleThemeIndex = 0;

  /// Whether battle audio is currently active (prevents area audio changes).
  bool _inBattle = false;

  /// Whether an async audio operation is in progress.
  bool _busy = false;

  /// Pending area change queued while busy.
  String? _pendingAreaChange;

  /// Pending battle state change queued while busy.
  bool? _pendingBattleChange;

  /// The area track that was playing when battle started (for restoration).
  String? _areaTrackBeforeBattle;

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
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) {
      try {
        await _audioService.stop();
      } catch (e) {
        debugPrint('AreaAudioManager.setEnabled stop error: $e');
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

  // ── Battle themes ──

  /// Whether battle audio is currently active.
  bool get inBattle => _inBattle;

  /// Returns the current battle themes list.
  List<String> get battleThemes => List.unmodifiable(_battleThemes);

  /// Adds a battle theme MP3 path to the end of the list.
  void addBattleTheme(String filePath) {
    _battleThemes.add(filePath);
  }

  /// Removes the battle theme at [index].
  void removeBattleThemeAt(int index) {
    if (index < 0 || index >= _battleThemes.length) return;
    _battleThemes.removeAt(index);
    if (_battleThemeIndex >= _battleThemes.length) {
      _battleThemeIndex = 0;
    }
  }

  /// Reorders battle themes (drag-and-drop support).
  void reorderBattleThemes(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final item = _battleThemes.removeAt(oldIndex);
    _battleThemes.insert(newIndex, item);
    _battleThemeIndex = 0;
  }

  /// Loads battle themes from a list (e.g., from settings storage).
  void loadBattleThemes(List<String> themes) {
    _battleThemes.clear();
    _battleThemes.addAll(themes);
    _battleThemeIndex = 0;
  }

  /// Drains the highest-priority pending operation after the current one.
  void _drainPending() {
    if (_pendingBattleChange != null) {
      final inBattle = _pendingBattleChange!;
      _pendingBattleChange = null;
      _pendingAreaChange = null;
      onBattleStateChanged(inBattle);
      return;
    }
    if (_pendingAreaChange != null) {
      final area = _pendingAreaChange!;
      _pendingAreaChange = null;
      onAreaChanged(area);
    }
  }

  /// Called when battle state transitions. Switches to/from battle audio.
  ///
  /// Returns the track path now playing, or null.
  Future<String?> onBattleStateChanged(bool inBattle) async {
    if (!_enabled) return null;
    if (_busy) {
      _pendingBattleChange = inBattle;
      return null;
    }
    _busy = true;

    try {
      if (inBattle && !_inBattle) {
        // Entering battle.
        _inBattle = true;
        if (_battleThemes.isEmpty) return null;

        // Save current area audio for restoration after battle.
        _areaTrackBeforeBattle = _audioService.currentTrackPath;

        final theme = _battleThemes[_battleThemeIndex];
        _battleThemeIndex = (_battleThemeIndex + 1) % _battleThemes.length;

        if (!await File(theme).exists()) return null;
        try {
          await _audioService.play(theme);
          return theme;
        } catch (e) {
          debugPrint('AreaAudioManager.onBattleStateChanged play error: $e');
          return null;
        }
      } else if (!inBattle && _inBattle) {
        // Leaving battle — restore area audio.
        _inBattle = false;
        final restorePath = _areaTrackBeforeBattle;
        _areaTrackBeforeBattle = null;

        if (restorePath != null && await File(restorePath).exists()) {
          try {
            await _audioService.play(restorePath);
            return restorePath;
          } catch (e) {
            debugPrint(
                'AreaAudioManager.onBattleStateChanged restore error: $e');
          }
        } else {
          try {
            await _audioService.stop();
          } catch (e) {
            debugPrint(
                'AreaAudioManager.onBattleStateChanged stop error: $e');
          }
        }
        return null;
      }
      return null;
    } finally {
      _busy = false;
      _drainPending();
    }
  }

  /// Called when the detected area changes. Triggers audio transition.
  ///
  /// This is the main entry point – call this whenever the area detector
  /// reports a new area.
  Future<void> onAreaChanged(String newArea) async {
    if (!_enabled) return;
    if (newArea == _currentPlayingArea) return;

    if (_busy) {
      _pendingAreaChange = newArea;
      return;
    }
    _busy = true;

    _currentPlayingArea = newArea;

    try {
      // During battle, update what we'll restore but don't change audio.
      if (_inBattle) {
        _areaTrackBeforeBattle = _resolveTrackPath(newArea);
        return;
      }

      final trackPath = _resolveTrackPath(newArea);

      if (trackPath == null) {
        // No track for this area – stop.
        try {
          await _audioService.stop();
        } catch (e) {
          debugPrint('AreaAudioManager.onAreaChanged stop error: $e');
        }
        return;
      }

      // Verify the file exists.
      if (!await File(trackPath).exists()) {
        try {
          await _audioService.stop();
        } catch (e) {
          debugPrint('AreaAudioManager.onAreaChanged stop error: $e');
        }
        return;
      }

      // Get area-specific volume.
      final areaConfig = _areaDetector.getAreaConfig(newArea);
      final volume = areaConfig?.audio?.volume ?? 0.7;

      // Play the new track.
      try {
        await _audioService.play(trackPath, volume: volume);
      } catch (e) {
        debugPrint('AreaAudioManager.onAreaChanged play error: $e');
      }
    } finally {
      _busy = false;
      _drainPending();
    }
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

  /// Stops all audio and resets session state.
  ///
  /// Battle themes list and index are preserved (user config).
  Future<void> reset() async {
    try {
      await _audioService.stop();
    } catch (e) {
      debugPrint('AreaAudioManager.reset error: $e');
    }
    _currentPlayingArea = null;
    _inBattle = false;
    _areaTrackBeforeBattle = null;
  }

  /// Cleans up manager state. Does NOT dispose the AudioService
  /// since it is a shared singleton owned by [audioServiceProvider].
  Future<void> dispose() async {
    _enabled = false;
    _currentPlayingArea = null;
  }
}
