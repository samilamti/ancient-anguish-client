import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/coord_area_config_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart';
import 'package:ancient_anguish_client/providers/login_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/coord_area_config.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';

void main() {
  late ProviderContainer container;
  late LoginNotifier notifier;
  late FakeConnectionService fakeService;

  setUp(() {
    fakeService = FakeConnectionService();
    container = ProviderContainer(
      overrides: [
        connectionServiceProvider.overrideWithValue(fakeService),
        terminalBufferProvider
            .overrideWith(() => _FakeTerminalBufferNotifier()),
        promptParserProvider.overrideWithValue(PromptParser()),
        areaDetectorProvider
            .overrideWith((ref) => Future.value(AreaDetector())),
        coordAreaConfigProvider.overrideWith(() {
          return _FakeCoordAreaConfigNotifier();
        }),
      ],
    );
    notifier = container.read(loginProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('LoginNotifier - state transitions', () {
    test('starts in LoginIdle', () {
      expect(container.read(loginProvider), isA<LoginIdle>());
    });

    test('onNamePromptDetected transitions to LoginPromptDetected', () {
      notifier.onNamePromptDetected();
      expect(container.read(loginProvider), isA<LoginPromptDetected>());
    });

    test('onNamePromptDetected only transitions from LoginIdle', () {
      notifier.onNamePromptDetected(); // → LoginPromptDetected
      notifier.submitGuest(); // → LoginComplete
      notifier.onNamePromptDetected(); // Should not change from LoginComplete.
      expect(container.read(loginProvider), isA<LoginComplete>());
    });
  });

  group('LoginNotifier - submitCredentials', () {
    test('sends name command and transitions to LoginComplete', () {
      notifier.onNamePromptDetected();
      notifier.submitCredentials('chosen', 'vinter', false);

      expect(fakeService.sentCommands, contains('chosen'));
      expect(container.read(loginProvider), isA<LoginComplete>());
    });

    test('sets player name with capitalized first letter', () {
      notifier.onNamePromptDetected();
      notifier.submitCredentials('chosen', 'vinter', false);

      final state = container.read(gameStateProvider);
      expect(state.playerName, 'Chosen');
    });
  });

  group('LoginNotifier - submitGuest', () {
    test('sends "guest" command', () {
      notifier.onNamePromptDetected();
      notifier.submitGuest();

      expect(fakeService.sentCommands, contains('guest'));
      expect(container.read(loginProvider), isA<LoginComplete>());
    });
  });

  group('LoginNotifier - onPasswordPromptDetected', () {
    test('sends password when pending', () {
      notifier.onNamePromptDetected();
      notifier.submitCredentials('chosen', 'secret123', false);
      fakeService.sentCommands.clear();

      notifier.onPasswordPromptDetected();

      expect(fakeService.sentCommands, contains('secret123'));
    });

    test('no-op when no pending password', () {
      fakeService.sentCommands.clear();
      notifier.onPasswordPromptDetected();
      expect(fakeService.sentCommands, isEmpty);
    });

    test('clears pending password after sending', () {
      notifier.onNamePromptDetected();
      notifier.submitCredentials('chosen', 'secret', false);
      fakeService.sentCommands.clear();

      notifier.onPasswordPromptDetected();
      expect(fakeService.sentCommands, hasLength(2)); // password + prompt cmd

      fakeService.sentCommands.clear();
      notifier.onPasswordPromptDetected(); // Should be no-op now.
      expect(fakeService.sentCommands, isEmpty);
    });
  });

  group('LoginNotifier - dismiss', () {
    test('returns to LoginIdle and clears pending', () {
      notifier.onNamePromptDetected();
      notifier.dismiss();
      expect(container.read(loginProvider), isA<LoginIdle>());
    });
  });

  group('LoginNotifier - reset', () {
    test('returns to LoginIdle and clears pending password', () {
      notifier.onNamePromptDetected();
      notifier.submitCredentials('chosen', 'pass', false);

      notifier.reset();
      expect(container.read(loginProvider), isA<LoginIdle>());

      // Pending password should be cleared.
      fakeService.sentCommands.clear();
      notifier.onPasswordPromptDetected();
      expect(fakeService.sentCommands, isEmpty);
    });
  });
}

/// Fake ConnectionService that records sent commands without opening a socket.
class FakeConnectionService extends ConnectionService {
  final List<String> sentCommands = [];

  @override
  void sendCommand(String command) {
    sentCommands.add(command);
  }
}

/// Fake terminal buffer notifier that does nothing (avoids connection setup).
class _FakeTerminalBufferNotifier extends TerminalBufferNotifier {
  @override
  List<StyledLine> build() => [];
}

/// Fake coord area config notifier.
class _FakeCoordAreaConfigNotifier extends CoordAreaConfigNotifier {
  @override
  CoordAreaConfig build() => CoordAreaConfig();
}
