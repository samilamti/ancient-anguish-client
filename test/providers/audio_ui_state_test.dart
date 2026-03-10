import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/audio_provider.dart';

void main() {
  group('AudioUiState - defaults', () {
    test('default constructor has correct initial values', () {
      const state = AudioUiState();
      expect(state.isPlaying, isFalse);
      expect(state.isMuted, isFalse);
      expect(state.masterVolume, 0.7);
      expect(state.currentArea, isNull);
      expect(state.currentTrackPath, isNull);
      expect(state.audioEnabled, isTrue);
    });
  });

  group('AudioUiState - copyWith sentinel pattern', () {
    test('preserves currentArea when not specified (sentinel default)', () {
      const state = AudioUiState(currentArea: 'Forest');
      final copied = state.copyWith(isPlaying: true);
      expect(copied.currentArea, 'Forest');
    });

    test('explicitly sets currentArea to null', () {
      const state = AudioUiState(currentArea: 'Forest');
      final copied = state.copyWith(currentArea: null);
      expect(copied.currentArea, isNull);
    });

    test('explicitly sets currentArea to a value', () {
      const state = AudioUiState();
      final copied = state.copyWith(currentArea: 'Castle');
      expect(copied.currentArea, 'Castle');
    });

    test('preserves currentTrackPath when not specified', () {
      const state = AudioUiState(currentTrackPath: 'music/track.mp3');
      final copied = state.copyWith(isPlaying: true);
      expect(copied.currentTrackPath, 'music/track.mp3');
    });

    test('explicitly sets currentTrackPath to null', () {
      const state = AudioUiState(currentTrackPath: 'music/track.mp3');
      final copied = state.copyWith(currentTrackPath: null);
      expect(copied.currentTrackPath, isNull);
    });

    test('explicitly sets currentTrackPath to a value', () {
      const state = AudioUiState();
      final copied = state.copyWith(currentTrackPath: 'new_track.mp3');
      expect(copied.currentTrackPath, 'new_track.mp3');
    });

    test('combines sentinel and normal fields in one call', () {
      const state = AudioUiState(
        currentArea: 'Town',
        currentTrackPath: 'old.mp3',
        isPlaying: false,
        masterVolume: 0.5,
      );
      final copied = state.copyWith(
        isPlaying: true,
        currentArea: null, // Explicitly clear area.
        masterVolume: 0.8,
        // currentTrackPath not specified — should be preserved.
      );
      expect(copied.isPlaying, isTrue);
      expect(copied.currentArea, isNull);
      expect(copied.currentTrackPath, 'old.mp3');
      expect(copied.masterVolume, 0.8);
    });
  });

  group('AudioUiState - copyWith normal fields', () {
    test('copies isPlaying', () {
      const state = AudioUiState();
      expect(state.copyWith(isPlaying: true).isPlaying, isTrue);
    });

    test('copies isMuted', () {
      const state = AudioUiState();
      expect(state.copyWith(isMuted: true).isMuted, isTrue);
    });

    test('copies masterVolume', () {
      const state = AudioUiState();
      expect(state.copyWith(masterVolume: 0.3).masterVolume, 0.3);
    });

    test('copies audioEnabled', () {
      const state = AudioUiState();
      expect(state.copyWith(audioEnabled: false).audioEnabled, isFalse);
    });
  });
}
