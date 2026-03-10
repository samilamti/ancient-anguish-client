import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

/// Low-level audio playback service.
///
/// Uses a single [AudioPlayer] instance. Switching tracks stops the current
/// track and starts the new one immediately (no crossfade).
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<PlaybackEvent> _eventSub;

  AudioService() {
    // Monitor player state for unexpected track completion.
    _stateSub = _player.playerStateStream.listen(
      _onPlayerStateChanged,
      onError: (_) {},
    );
    // Absorb platform-level errors (e.g., "Operation aborted" on Windows)
    // that just_audio emits on the playback event stream. These are on a
    // separate stream from playerStateStream and must be caught independently.
    _eventSub = _player.playbackEventStream.listen(null, onError: (_) {});
  }

  double _masterVolume = AudioDefaults.masterVolume;
  bool _muted = false;
  String? _currentTrackPath;
  bool _isPlaying = false;
  bool _busy = false;

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
      _player.setVolume(_masterVolume);
    }
  }

  /// Toggles mute on/off.
  void toggleMute() {
    _muted = !_muted;
    if (_isPlaying) {
      _player.setVolume(_muted ? 0.0 : _masterVolume);
    }
  }

  /// Sets mute state explicitly.
  void setMuted(bool muted) {
    _muted = muted;
    if (_isPlaying) {
      _player.setVolume(_muted ? 0.0 : _masterVolume);
    }
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
      await stop();

      await _player.setFilePath(filePath);
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(_muted ? 0.0 : volume * _masterVolume);
      await _player.play();
      _currentTrackPath = filePath;
      _isPlaying = true;
    } catch (e) {
      _isPlaying = false;
      _currentTrackPath = null;
    } finally {
      _busy = false;
    }
  }

  /// Stops all playback.
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    _isPlaying = false;
    _currentTrackPath = null;
  }

  /// Pauses the current playback.
  Future<void> pause() async {
    if (_isPlaying) {
      await _player.pause();
    }
  }

  /// Resumes paused playback.
  Future<void> resume() async {
    if (_isPlaying) {
      await _player.play();
    }
  }

  /// Disposes the audio player. Call when the service is no longer needed.
  Future<void> dispose() async {
    await stop();
    await _stateSub.cancel();
    await _eventSub.cancel();
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('AudioService: _player.dispose() error: $e');
    }
  }

  // ── Helpers ──

  /// Detects when the player unexpectedly reaches completed state
  /// (e.g., LoopMode.one failed on Windows). Resets [_isPlaying] to prevent
  /// subsequent operations from acting on a player in a bad state.
  void _onPlayerStateChanged(PlayerState playerState) {
    if (!_isPlaying) return;
    if (playerState.processingState == ProcessingState.completed) {
      debugPrint(
          'AudioService: player completed unexpectedly, resetting state');
      _isPlaying = false;
      _currentTrackPath = null;
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
