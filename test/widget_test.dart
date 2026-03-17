import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ancient_anguish_client/app.dart';
import 'package:ancient_anguish_client/providers/app_init_provider.dart';
import 'package:ancient_anguish_client/providers/audio_provider.dart';
import 'package:ancient_anguish_client/services/audio/audio_interface.dart';

/// Minimal no-op [AudioInterface] for widget tests.
///
/// Avoids loading the native SoLoud DLL which is unavailable in the test
/// environment.
class _StubAudioService implements AudioInterface {
  @override
  double get masterVolume => 0.7;

  @override
  bool get isMuted => false;

  @override
  bool get isPlaying => false;

  @override
  String? get currentTrackPath => null;

  @override
  VoidCallback? onTrackFinished;

  @override
  Future<void> play(String filePath,
          {double volume = 0.7,
          bool looping = true,
          int fadeInMs = 500,
          int fadeOutMs = 500}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> fadeOutAndStop({int fadeOutMs = 500}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  void setMasterVolume(double volume) {}

  @override
  void toggleMute() {}

  @override
  void setMuted(bool muted) {}

  @override
  Future<bool> canPlay(String path) async => false;

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appInitProvider.overrideWith((ref) async {}),
          audioServiceProvider.overrideWithValue(_StubAudioService()),
        ],
        child: const AncientAnguishApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the app title is shown.
    expect(find.text('Ancient Anguish'), findsOneWidget);
  });
}
