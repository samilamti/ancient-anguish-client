import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;
import 'package:web/web.dart' as web;

import 'audio_interface.dart';

/// Web implementation of [AudioInterface] using HTML5 Audio API.
///
/// Plays audio files by streaming from the server's audio API endpoint.
/// Supports crossfade between tracks using two [HTMLAudioElement] instances.
class WebAudioService implements AudioInterface {
  WebAudioService({
    required String baseUrl,
    required String Function() tokenProvider,
  })  : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider;

  final String _baseUrl;
  final String Function() _tokenProvider;

  web.HTMLAudioElement? _currentAudio;
  web.HTMLAudioElement? _fadingOutAudio;
  Timer? _fadeTimer;

  double _masterVolume = 0.7;
  bool _isMuted = false;
  bool _isPlaying = false;
  String? _currentTrackPath;

  @override
  double get masterVolume => _masterVolume;

  @override
  bool get isMuted => _isMuted;

  @override
  bool get isPlaying => _isPlaying;

  @override
  String? get currentTrackPath => _currentTrackPath;

  @override
  VoidCallback? onTrackFinished;

  /// Converts a file path to an audio API URL.
  ///
  /// Strips directory paths, keeping only the filename.
  String _audioUrl(String filePath) {
    final fileName = filePath.split('/').last.split('\\').last;
    final token = _tokenProvider();
    return '$_baseUrl/api/audio/${Uri.encodeComponent(fileName)}?token=$token';
  }

  double get _effectiveVolume => _isMuted ? 0.0 : _masterVolume;

  @override
  Future<void> play(
    String filePath, {
    double volume = 0.7,
    bool looping = true,
    int fadeInMs = 2000,
    int fadeOutMs = 2000,
  }) async {
    // Same track already playing — no-op.
    if (_currentTrackPath == filePath && _isPlaying) return;

    try {
      // Fade out current track.
      if (_currentAudio != null && _isPlaying) {
        _fadingOutAudio = _currentAudio;
        _startFadeOut(_fadingOutAudio!, fadeOutMs);
      }

      // Create new audio element.
      final audio = web.HTMLAudioElement()
        ..src = _audioUrl(filePath)
        ..loop = looping
        ..volume = 0.0; // Start silent for fade in.

      _currentAudio = audio;
      _currentTrackPath = filePath;
      _isPlaying = true;

      // Listen for track end (non-looping).
      if (!looping) {
        audio.onEnded.listen((_) {
          if (_currentAudio == audio) {
            _isPlaying = false;
            _currentTrackPath = null;
            onTrackFinished?.call();
          }
        });
      }

      // Listen for errors.
      audio.onError.listen((_) {
        debugPrint('WebAudioService: Audio error for $filePath');
        if (_currentAudio == audio) {
          _isPlaying = false;
          _currentTrackPath = null;
        }
      });

      await audio.play().toDart;

      // Fade in.
      _startFadeIn(audio, volume * _effectiveVolume, fadeInMs);
    } catch (e) {
      debugPrint('WebAudioService.play($filePath): $e');
      _isPlaying = false;
    }
  }

  void _startFadeIn(web.HTMLAudioElement audio, double targetVolume, int ms) {
    if (ms <= 0) {
      audio.volume = targetVolume;
      return;
    }
    const stepMs = 50;
    final steps = ms ~/ stepMs;
    final increment = targetVolume / steps;
    var currentStep = 0;

    Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      currentStep++;
      if (currentStep >= steps || audio != _currentAudio) {
        audio.volume = targetVolume.clamp(0.0, 1.0);
        timer.cancel();
        return;
      }
      audio.volume = (increment * currentStep).clamp(0.0, 1.0);
    });
  }

  void _startFadeOut(web.HTMLAudioElement audio, int ms) {
    if (ms <= 0) {
      audio.pause();
      return;
    }
    final startVolume = audio.volume;
    const stepMs = 50;
    final steps = ms ~/ stepMs;
    final decrement = startVolume / steps;
    var currentStep = 0;

    Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      currentStep++;
      if (currentStep >= steps) {
        audio.pause();
        audio.volume = 0.0;
        if (_fadingOutAudio == audio) _fadingOutAudio = null;
        timer.cancel();
        return;
      }
      audio.volume = (startVolume - decrement * currentStep).clamp(0.0, 1.0);
    });
  }

  @override
  Future<void> stop() async {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _currentAudio?.pause();
    _fadingOutAudio?.pause();
    _currentAudio = null;
    _fadingOutAudio = null;
    _isPlaying = false;
    _currentTrackPath = null;
  }

  @override
  Future<void> fadeOutAndStop({int fadeOutMs = 2000}) async {
    if (_currentAudio != null && _isPlaying) {
      _startFadeOut(_currentAudio!, fadeOutMs);
      await Future<void>.delayed(Duration(milliseconds: fadeOutMs));
    }
    _currentAudio = null;
    _isPlaying = false;
    _currentTrackPath = null;
  }

  @override
  Future<void> pause() async {
    _currentAudio?.pause();
    _isPlaying = false;
  }

  @override
  Future<void> resume() async {
    if (_currentAudio != null) {
      try {
        await _currentAudio!.play().toDart;
        _isPlaying = true;
      } catch (e) {
        debugPrint('WebAudioService.resume: $e');
      }
    }
  }

  @override
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
    _applyVolume();
  }

  @override
  void toggleMute() {
    _isMuted = !_isMuted;
    _applyVolume();
  }

  @override
  void setMuted(bool muted) {
    _isMuted = muted;
    _applyVolume();
  }

  void _applyVolume() {
    if (_currentAudio != null) {
      _currentAudio!.volume = _effectiveVolume;
    }
  }

  @override
  Future<bool> canPlay(String path) async {
    // On web, assume audio is always available (server handles 404s).
    return true;
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
