import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import 'audio_interface.dart';

/// Native audio playback service using SoLoud C engine via FFI.
///
/// Desktop-only implementation of [AudioInterface].
/// The engine is lazily initialized on first [play] call.
class NativeAudioService implements AudioInterface {
  late final SoLoud _soloud;
  final bool _testMode;

  bool _initialized = false;
  AudioSource? _currentSource;
  AudioSource? _previousSource;
  SoundHandle? _currentHandle;
  StreamSubscription<void>? _finishedSub;

  double _masterVolume = AudioDefaults.masterVolume;
  bool _muted = false;
  String? _currentTrackPath;
  bool _isPlaying = false;
  bool _busy = false;
  double _trackVolume = 0.7;

  @override
  VoidCallback? onTrackFinished;

  NativeAudioService()
      : _testMode = false,
        _soloud = SoLoud.instance;

  /// Creates a NativeAudioService that skips all native SoLoud calls.
  ///
  /// Use in tests to exercise state-management logic (busy flag,
  /// same-track detection, volume/mute) without requiring the native library.
  @visibleForTesting
  NativeAudioService.forTesting() : _testMode = true;

  @override
  double get masterVolume => _masterVolume;

  @override
  bool get isMuted => _muted;

  @override
  bool get isPlaying => _isPlaying;

  @override
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

  @override
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
    _applyVolume();
  }

  @override
  void toggleMute() {
    _muted = !_muted;
    _applyVolume();
  }

  @override
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

  @override
  Future<void> play(
    String filePath, {
    double volume = 0.7,
    bool looping = true,
    int fadeInMs = AudioDefaults.fadeInMs,
    int fadeOutMs = AudioDefaults.fadeOutMs,
  }) async {
    if (filePath == _currentTrackPath && _isPlaying) return;
    if (_busy) return;
    _busy = true;
    try {
      await _ensureInitialized();

      _trackVolume = volume;

      if (_testMode) {
        _currentTrackPath = filePath;
        _isPlaying = true;
        return;
      }

      // Dispose the source from two play() calls ago. By now its fade-out
      // has long finished, so the C++ sound hash is safe to remove.
      if (_previousSource != null) {
        try {
          await _soloud.disposeSource(_previousSource!);
        } catch (e) {
          debugPrint('AudioService: disposeSource error: $e');
        }
        _previousSource = null;
      }

      // Crossfade: schedule the old handle to fade out and stop.
      if (_currentHandle != null) {
        try {
          final fadeDuration = Duration(milliseconds: fadeOutMs);
          _soloud.fadeVolume(_currentHandle!, 0.0, fadeDuration);
          _soloud.scheduleStop(_currentHandle!, fadeDuration);
        } catch (e) {
          debugPrint('AudioService: crossfade-out error: $e');
          // Fall back to immediate stop.
          try {
            _soloud.stop(_currentHandle!);
          } catch (_) {}
        }
      }
      _currentHandle = null;
      _isPlaying = false;
      _currentTrackPath = null;

      // Track the current source for disposal on the NEXT play() call.
      // It may still be fading out, so we must not dispose it yet.
      if (_currentSource != null) {
        _previousSource = _currentSource;
        _currentSource = null;
      }

      _currentSource = await _soloud.loadFile(filePath);

      // Listen for track completion.
      _finishedSub?.cancel();
      _finishedSub = _currentSource!.allInstancesFinished.listen((_) {
        _onAllInstancesFinished();
      });

      // Start at volume 0 and fade in.
      _currentHandle = await _soloud.play(
        _currentSource!,
        looping: looping,
        volume: 0.0,
      );
      _soloud.fadeVolume(
        _currentHandle!,
        _effectiveVolume,
        Duration(milliseconds: fadeInMs),
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

  @override
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

  @override
  Future<void> fadeOutAndStop({
    int fadeOutMs = AudioDefaults.fadeOutMs,
  }) async {
    if (!_isPlaying && _currentHandle == null) return;
    if (!_testMode && _currentHandle != null) {
      try {
        final fadeDuration = Duration(milliseconds: fadeOutMs);
        _soloud.fadeVolume(_currentHandle!, 0.0, fadeDuration);
        _soloud.scheduleStop(_currentHandle!, fadeDuration);
      } catch (e) {
        debugPrint('AudioService.fadeOutAndStop error: $e');
        // Fall back to immediate stop.
        try {
          _soloud.stop(_currentHandle!);
        } catch (_) {}
      }
    }
    _currentHandle = null;
    _isPlaying = false;
    _currentTrackPath = null;
  }

  @override
  Future<void> pause() async {
    if (_isPlaying && _currentHandle != null && !_testMode) {
      try {
        _soloud.setPause(_currentHandle!, true);
      } catch (e) {
        debugPrint('AudioService.pause error: $e');
      }
    }
  }

  @override
  Future<void> resume() async {
    if (_isPlaying && _currentHandle != null && !_testMode) {
      try {
        _soloud.setPause(_currentHandle!, false);
      } catch (e) {
        debugPrint('AudioService.resume error: $e');
      }
    }
  }

  @override
  Future<bool> canPlay(String path) => File(path).exists();

  @override
  Future<void> dispose() async {
    await stop();
    _finishedSub?.cancel();
    _finishedSub = null;
    for (final source in [_currentSource, _previousSource]) {
      if (!_testMode && source != null) {
        try {
          await _soloud.disposeSource(source);
        } catch (e) {
          debugPrint('AudioService: disposeSource error: $e');
        }
      }
    }
    _currentSource = null;
    _previousSource = null;
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
  /// For non-looping tracks this fires the [onTrackFinished] callback.
  void _onAllInstancesFinished() {
    if (!_isPlaying) return;
    debugPrint('AudioService: track finished');
    _isPlaying = false;
    _currentTrackPath = null;
    _currentHandle = null;
    onTrackFinished?.call();
  }

  /// Simulates a track finishing (for tests).
  @visibleForTesting
  void simulateTrackFinished() {
    _onAllInstancesFinished();
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
