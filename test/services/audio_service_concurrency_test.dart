import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/audio/audio_service.dart';

/// Stubs the just_audio method channel so AudioPlayer operations don't throw
/// MissingPluginException in unit tests.
void _stubJustAudioPlatform() {
  const methodChannel = MethodChannel('com.ryanheise.just_audio.methods');
  int nextId = 0;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
    switch (call.method) {
      case 'init':
        return {'id': 'player_${nextId++}'};
      case 'disposePlayer':
      case 'disposeAllPlayers':
        return {};
      default:
        return null;
    }
  });
}

/// Stubs per-player channels created by just_audio.
void _stubPlayerChannel(String id) {
  final channel = MethodChannel('com.ryanheise.just_audio.methods.$id');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    switch (call.method) {
      case 'load':
        return {'duration': 60000000}; // 60s in microseconds.
      case 'play':
      case 'pause':
      case 'stop':
      case 'setVolume':
      case 'setLoopMode':
      case 'setSpeed':
      case 'seek':
      case 'dispose':
        return {};
      default:
        return null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _stubJustAudioPlatform();

  // Stub player channels for the players AudioService will create.
  for (var i = 0; i < 10; i++) {
    _stubPlayerChannel('player_$i');
  }

  late AudioService service;

  setUp(() {
    service = AudioService();
  });

  tearDown(() async {
    await service.dispose();
  });

  group('AudioService - Operation serialization', () {
    test('concurrent play calls leave consistent state', () async {
      final f1 = service.play('/path/a.mp3');
      final f2 = service.play('/path/b.mp3');
      await Future.wait([f1, f2]);

      if (service.isPlaying) {
        expect(service.currentTrackPath, isNotNull);
      } else {
        expect(service.currentTrackPath, isNull);
      }
    });

    test('concurrent stop calls are safe', () async {
      await Future.wait([service.stop(), service.stop(), service.stop()]);
      expect(service.isPlaying, false);
      expect(service.currentTrackPath, isNull);
    });

    test('stop after play resets state', () async {
      await service.play('/path/track.mp3');
      await service.stop();
      expect(service.isPlaying, false);
      expect(service.currentTrackPath, isNull);
    });

    test('play same track while playing is a no-op', () async {
      await service.play('/path/a.mp3');
      final trackBefore = service.currentTrackPath;
      final playingBefore = service.isPlaying;

      // Same track again — should return immediately.
      await service.play('/path/a.mp3');
      expect(service.currentTrackPath, trackBefore);
      expect(service.isPlaying, playingBefore);
    });
  });
}
