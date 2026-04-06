import 'package:flutter/foundation.dart';

/// Abstract interface for audio playback.
///
/// Desktop: [NativeAudioService] uses flutter_soloud (FFI/SoLoud C engine).
/// Web: will use HTML5 Audio API via dart:js_interop.
abstract class AudioInterface {
  /// Current master volume (0.0 – 1.0).
  double get masterVolume;

  /// Whether audio is muted.
  bool get isMuted;

  /// Whether audio is currently playing.
  bool get isPlaying;

  /// The file path (or URL) of the currently playing track, or null.
  String? get currentTrackPath;

  /// Called when a non-looping track finishes playing.
  VoidCallback? onTrackFinished;

  /// Plays a track with crossfade. Fades out any current playback while
  /// fading in the new track.
  ///
  /// [filePath] is a local file path (desktop) or URL (web).
  /// If the same track is already playing, this is a no-op.
  Future<void> play(
    String filePath, {
    double volume = 0.7,
    bool looping = true,
    int fadeInMs,
    int fadeOutMs,
  });

  /// Stops all playback.
  Future<void> stop();

  /// Fades out and stops playback over [fadeOutMs] milliseconds.
  Future<void> fadeOutAndStop({int fadeOutMs});

  /// Pauses the current playback.
  Future<void> pause();

  /// Resumes paused playback.
  Future<void> resume();

  /// Sets the master volume (0.0 – 1.0).
  void setMasterVolume(double volume);

  /// Toggles mute on/off.
  void toggleMute();

  /// Sets mute state explicitly.
  void setMuted(bool muted);

  /// Whether the given track path can be played.
  ///
  /// Desktop: checks that the local file exists.
  /// Web: always returns true (server handles missing files gracefully).
  Future<bool> canPlay(String path);

  /// Disposes the audio engine. Call when the service is no longer needed.
  Future<void> dispose();
}
