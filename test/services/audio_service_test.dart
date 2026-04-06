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

  group('AudioService - Volume', () {
    test('default volume is 0.7', () {
      expect(service.masterVolume, 0.7);
    });

    test('setMasterVolume clamps to 0-1 range', () {
      service.setMasterVolume(1.5);
      expect(service.masterVolume, 1.0);

      service.setMasterVolume(-0.5);
      expect(service.masterVolume, 0.0);

      service.setMasterVolume(0.5);
      expect(service.masterVolume, 0.5);
    });

    test('toggleMute flips muted state', () {
      expect(service.isMuted, false);
      service.toggleMute();
      expect(service.isMuted, true);
      service.toggleMute();
      expect(service.isMuted, false);
    });

    test('setMuted sets explicit state', () {
      service.setMuted(true);
      expect(service.isMuted, true);
      service.setMuted(false);
      expect(service.isMuted, false);
    });
  });

  group('AudioService - State', () {
    test('starts not playing', () {
      expect(service.isPlaying, false);
      expect(service.currentTrackPath, isNull);
    });

    test('stop resets playback state', () async {
      await service.stop();
      expect(service.isPlaying, false);
      expect(service.currentTrackPath, isNull);
    });
  });
}
