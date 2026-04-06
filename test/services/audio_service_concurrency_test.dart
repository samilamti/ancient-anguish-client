import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/audio/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NativeAudioService service;

  setUp(() {
    service = NativeAudioService.forTesting();
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
