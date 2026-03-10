import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

/// Low-level audio playback service with dual-player crossfade support.
///
/// Uses two [AudioPlayer] instances to enable smooth crossfading between
/// area soundtracks. While one player fades out, the other fades in with
/// the new track.
class AudioService {
  final AudioPlayer _playerA = AudioPlayer();
  final AudioPlayer _playerB = AudioPlayer();
  bool _aIsActive = true;

  double _masterVolume = AudioDefaults.masterVolume;
  bool _muted = false;
  String? _currentTrackPath;
  bool _isPlaying = false;
  bool _busy = false;

  /// The currently active player.
  AudioPlayer get _active => _aIsActive ? _playerA : _playerB;

  /// The inactive (standby) player.
  AudioPlayer get _inactive => _aIsActive ? _playerB : _playerA;

  /// Current master volume (0.0 – 1.0).
  double get masterVolume => _masterVolume;

  /// Whether audio is muted.
  bool get isMuted => _muted;

  /// Whether audio is currently playing.
  bool get isPlaying => _isPlaying;

  /// The file path of the currently playing track, or null.
  String? get currentTrackPath => _currentTrackPath;

  /// Sets the master volume (0.0 – 1.0).
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
    if (_isPlaying && !_muted) {
      _active.setVolume(_masterVolume);
    }
  }

  /// Toggles mute on/off.
  void toggleMute() {
    _muted = !_muted;
    if (_isPlaying) {
      _active.setVolume(_muted ? 0.0 : _masterVolume);
    }
  }

  /// Sets mute state explicitly.
  void setMuted(bool muted) {
    _muted = muted;
    if (_isPlaying) {
      _active.setVolume(_muted ? 0.0 : _masterVolume);
    }
  }

  /// Plays a track immediately (no crossfade). Stops any current playback.
  Future<void> play(String filePath, {double volume = 0.7}) async {
    if (_busy) return;
    _busy = true;
    try {
      await stop();

      await _active.setFilePath(filePath);
      await _active.setLoopMode(LoopMode.one);
      await _active.setVolume(_muted ? 0.0 : volume * _masterVolume);
      await _active.play();
      _currentTrackPath = filePath;
      _isPlaying = true;
    } catch (e) {
      _isPlaying = false;
      _currentTrackPath = null;
    } finally {
      _busy = false;
    }
  }

  /// Crossfades from the current track to a new track.
  ///
  /// The inactive player loads and starts the new track at zero volume,
  /// then both players fade simultaneously over [fadeOutMs]/[fadeInMs].
  /// After the fade, the old player stops and the players swap roles.
  ///
  /// If nothing is currently playing, the new track fades in from silence.
  ///
  /// Concurrent calls are dropped to prevent player state corruption.
  Future<void> crossfadeTo(
    String filePath, {
    double volume = 0.7,
    int fadeOutMs = AudioDefaults.crossfadeDurationMs,
    int fadeInMs = AudioDefaults.crossfadeDurationMs,
  }) async {
    // If same track, do nothing.
    if (filePath == _currentTrackPath && _isPlaying) return;
    if (_busy) return;
    _busy = true;

    // Capture player references and state before any await points to prevent
    // TOCTOU races if another operation changes _aIsActive mid-crossfade.
    final oldPlayer = _active;
    final newPlayer = _inactive;
    final wasPlaying = _isPlaying;

    final effectiveVolume = volume * _masterVolume;
    final targetVolume = _muted ? 0.0 : effectiveVolume;

    try {
      // Load new track on inactive player.
      await newPlayer.setFilePath(filePath);
      await newPlayer.setLoopMode(LoopMode.one);
      await newPlayer.setVolume(0.0);
      await newPlayer.play();

      // Parallel fade: out active, in inactive.
      if (wasPlaying) {
        await Future.wait([
          _fadeVolume(oldPlayer, oldPlayer.volume, 0.0, fadeOutMs),
          _fadeVolume(newPlayer, 0.0, targetVolume, fadeInMs),
        ]);
        await oldPlayer.stop();
      } else {
        await _fadeVolume(newPlayer, 0.0, targetVolume, fadeInMs);
      }

      // Swap players.
      _aIsActive = !_aIsActive;
      _currentTrackPath = filePath;
      _isPlaying = true;
    } catch (e) {
      // If crossfade fails, try to at least keep the old track playing.
      // Graceful degradation.
      try {
        await newPlayer.stop();
      } catch (_) {}
    } finally {
      _busy = false;
    }
  }

  /// Stops all playback.
  Future<void> stop() async {
    try {
      await _playerA.stop();
    } catch (_) {}
    try {
      await _playerB.stop();
    } catch (_) {}
    _isPlaying = false;
    _currentTrackPath = null;
  }

  /// Pauses the current playback.
  Future<void> pause() async {
    if (_isPlaying) {
      await _active.pause();
    }
  }

  /// Resumes paused playback.
  Future<void> resume() async {
    if (_isPlaying) {
      await _active.play();
    }
  }

  /// Fades out and stops. Useful for entering areas with no audio.
  ///
  /// Concurrent calls are dropped to prevent player state corruption.
  Future<void> fadeOut({int durationMs = AudioDefaults.crossfadeDurationMs}) async {
    if (!_isPlaying) return;
    if (_busy) return;
    _busy = true;
    try {
      final player = _active;
      await _fadeVolume(player, player.volume, 0.0, durationMs);
      await stop();
    } finally {
      _busy = false;
    }
  }

  /// Disposes both audio players. Call when the service is no longer needed.
  Future<void> dispose() async {
    await stop();
    await _playerA.dispose();
    await _playerB.dispose();
  }

  // ── Helpers ──

  /// Smoothly fades a player's volume from [from] to [to] over [durationMs].
  Future<void> _fadeVolume(
    AudioPlayer player,
    double from,
    double to,
    int durationMs,
  ) async {
    const steps = AudioDefaults.fadeSteps;
    final stepDuration = Duration(milliseconds: durationMs ~/ steps);
    final stepSize = (to - from) / steps;

    for (var i = 1; i <= steps; i++) {
      final volume = (from + stepSize * i).clamp(0.0, 1.0);
      try {
        await player.setVolume(volume);
      } catch (_) {
        return; // Player may have been disposed.
      }
      await Future.delayed(stepDuration);
    }
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
