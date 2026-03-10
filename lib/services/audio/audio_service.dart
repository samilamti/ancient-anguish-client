import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

/// Low-level audio playback service.
///
/// Uses [flutter_soloud] (SoLoud C engine via FFI) for playback.
/// The engine is lazily initialized on first [play] call.
class AudioService {
  late final SoLoud _soloud;
  final bool _testMode;

  bool _initialized = false;
  AudioSource? _currentSource;
  SoundHandle? _currentHandle;
  StreamSubscription<void>? _finishedSub;

  double _masterVolume = AudioDefaults.masterVolume;
  bool _muted = false;
  String? _currentTrackPath;
  bool _isPlaying = false;
  bool _busy = false;
  double _trackVolume = 0.7;

  AudioService()
      : _testMode = false,
        _soloud = SoLoud.instance;

  /// Creates an AudioService that skips all native SoLoud calls.
  ///
  /// Use in tests to exercise state-management logic (busy flag,
  /// same-track detection, volume/mute) without requiring the native library.
  @visibleForTesting
  AudioService.forTesting() : _testMode = true;

  /// Current master volume (0.0 – 1.0).
  double get masterVolume => _masterVolume;

  /// Whether audio is muted.
  bool get isMuted => _muted;

  /// Whether audio is currently playing.
  bool get isPlaying => _isPlaying;

  /// The file path of the currently playing track, or null.
  String? get currentTrackPath => _currentTrackPath;

  // ── Volume helpers ──

  double get _effectiveVolume => _muted ? 0.0 : _trackVolume * _masterVolume;

  void _applyVolume() {
    if (_testMode || !_isPlaying || _currentHandle == null) return;
    try {
      _soloud.setVolume(_currentHandle!, _effectiveVolume);
    } catch (e) {
      debugPrint('AudioService._applyVolume error: $e');
    }
  }

  /// Sets the master volume (0.0 – 1.0).
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
    _applyVolume();
  }

  /// Toggles mute on/off.
  void toggleMute() {
    _muted = !_muted;
    _applyVolume();
  }

  /// Sets mute state explicitly.
  void setMuted(bool muted) {
    _muted = muted;
    _applyVolume();
  }

  // ── Engine lifecycle ──

  Future<void> _ensureInitialized() async {
    if (_testMode || _initialized) return;
    await _soloud.init();
    _initialized = true;
  }

  /// Plays a track. Stops any current playback first.
  ///
  /// If the same track is already playing, this is a no-op.
  /// Concurrent calls are dropped to prevent player state corruption.
  Future<void> play(String filePath, {double volume = 0.7}) async {
    if (filePath == _currentTrackPath && _isPlaying) return;
    if (_busy) return;
    _busy = true;
    try {
      await _ensureInitialized();
      await stop();

      _trackVolume = volume;

      if (_testMode) {
        _currentTrackPath = filePath;
        _isPlaying = true;
        return;
      }

      // Dispose previous source if loaded.
      if (_currentSource != null) {
        try {
          await _soloud.disposeSource(_currentSource!);
        } catch (e) {
          debugPrint('AudioService: disposeSource error: $e');
        }
        _currentSource = null;
      }

      _currentSource = await _soloud.loadFile(filePath);

      // Safety net: detect unexpected completion (shouldn't fire with looping).
      _finishedSub?.cancel();
      _finishedSub = _currentSource!.allInstancesFinished.listen((_) {
        _onAllInstancesFinished();
      });

      _currentHandle = await _soloud.play(
        _currentSource!,
        looping: true,
        volume: _effectiveVolume,
      );
      _currentTrackPath = filePath;
      _isPlaying = true;
    } catch (e) {
      debugPrint('AudioService.play error: $e');
      _isPlaying = false;
      _currentTrackPath = null;
      _currentHandle = null;
    } finally {
      _busy = false;
    }
  }

  /// Stops all playback.
  Future<void> stop() async {
    if (!_testMode && _currentHandle != null) {
      try {
        _soloud.stop(_currentHandle!);
      } catch (e) {
        debugPrint('AudioService.stop error: $e');
      }
    }
    _currentHandle = null;
    _isPlaying = false;
    _currentTrackPath = null;
  }

  /// Pauses the current playback.
  Future<void> pause() async {
    if (_isPlaying && _currentHandle != null && !_testMode) {
      try {
        _soloud.setPause(_currentHandle!, true);
      } catch (e) {
        debugPrint('AudioService.pause error: $e');
      }
    }
  }

  /// Resumes paused playback.
  Future<void> resume() async {
    if (_isPlaying && _currentHandle != null && !_testMode) {
      try {
        _soloud.setPause(_currentHandle!, false);
      } catch (e) {
        debugPrint('AudioService.resume error: $e');
      }
    }
  }

  /// Disposes the audio engine. Call when the service is no longer needed.
  Future<void> dispose() async {
    await stop();
    _finishedSub?.cancel();
    _finishedSub = null;
    if (!_testMode && _currentSource != null) {
      try {
        await _soloud.disposeSource(_currentSource!);
      } catch (e) {
        debugPrint('AudioService: disposeSource error: $e');
      }
    }
    _currentSource = null;
    if (!_testMode && _initialized) {
      try {
        _soloud.deinit();
      } catch (e) {
        debugPrint('AudioService: deinit error: $e');
      }
      _initialized = false;
    }
  }

  // ── Helpers ──

  /// Detects when SoLoud reports all instances of the current source finished.
  /// With looping enabled this should never fire, but serves as a safety net.
  void _onAllInstancesFinished() {
    if (!_isPlaying) return;
    debugPrint(
        'AudioService: sound finished unexpectedly, resetting state');
    _isPlaying = false;
    _currentTrackPath = null;
    _currentHandle = null;
  }

  /// Returns the path to the audio cache directory.
  static Future<String> getAudioCacheDir() async {
    final appDir = await getApplicationSupportDirectory();
    final audioDir = Directory('${appDir.path}/audio_cache');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir.path;
  }
}
