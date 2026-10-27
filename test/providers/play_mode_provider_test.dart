import 'package:ancient_anguish_client/providers/play_mode_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  PlayModeNotifier mode() => container.read(playModeProvider.notifier);
  PlayMode current() => container.read(playModeProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('starts off', () {
    expect(current(), PlayMode.off);
  });

  test('toggle turns it on and off and persists the choice', () {
    mode().toggle();
    expect(current(), PlayMode.play);
    expect(container.read(settingsProvider).playModeEnabled, isTrue);
    mode().toggle();
    expect(current(), PlayMode.off);
    expect(container.read(settingsProvider).playModeEnabled, isFalse);
  });

  test('Enter opens the input, sending closes it again', () {
    mode().toggle();
    mode().openInput();
    expect(current(), PlayMode.input);
    mode().closeInput();
    expect(current(), PlayMode.play);
  });

  test('input open/close does nothing while play mode is off', () {
    mode().openInput();
    expect(current(), PlayMode.off);
    mode().closeInput();
    expect(current(), PlayMode.off);
  });

  test('toggling off from the open input goes straight to off', () {
    mode().toggle();
    mode().openInput();
    mode().toggle();
    expect(current(), PlayMode.off);
  });

  test('follows settings loaded later', () {
    current();
    container.read(settingsProvider.notifier).setPlayModeEnabled(true);
    expect(current(), PlayMode.play);
  });

  test('settings round-trip the flag', () {
    final s = AppSettings.fromJson(
        const AppSettings(playModeEnabled: true).toJson());
    expect(s.playModeEnabled, isTrue);
    expect(AppSettings.fromJson(const {}).playModeEnabled, isFalse);
  });
}
