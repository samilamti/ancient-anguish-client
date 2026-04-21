import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/connection_info.dart';
import 'package:ancient_anguish_client/protocol/telnet/telnet_events.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/connection/connection_interface.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';

/// Tests the debounced prompt-flush timer in [TerminalBufferNotifier].
///
/// The AA server sends prompts without any terminator (`\n`, `IAC GA`, or
/// `IAC EOR`). The notifier schedules a 150 ms timer after each
/// [TelnetDataEvent] that leaves pending data in the parser; when the timer
/// fires without further data arriving, the buffered text is emitted as a
/// line so the user sees the prompt.
void main() {
  late _FakeConnectionService fakeService;
  late ProviderContainer container;

  ProviderContainer newContainer() => ProviderContainer(
        overrides: [
          connectionServiceProvider.overrideWithValue(fakeService),
          promptParserProvider.overrideWithValue(PromptParser()),
          areaDetectorProvider
              .overrideWith((ref) => Future.value(AreaDetector())),
          unifiedAreaConfigProvider.overrideWith(
              (ref) => Future.value(UnifiedAreaConfigManager())),
        ],
      );

  setUp(() {
    fakeService = _FakeConnectionService();
  });

  tearDown(() {
    container.dispose();
  });

  test('flushes pending partial line as a prompt after 150 ms', () {
    fakeAsync((async) {
      container = newContainer();
      // Attach the terminal buffer notifier so it starts listening.
      container.read(terminalBufferProvider.notifier);

      // Server sends "What is your name: " with no terminator.
      fakeService.emit(TelnetDataEvent(
        Uint8List.fromList('What is your name: '.codeUnits),
      ));

      // Microtask flush so the stream listener runs.
      async.flushMicrotasks();

      // Still within debounce window — nothing emitted yet.
      expect(container.read(terminalBufferProvider), isEmpty);

      async.elapse(const Duration(milliseconds: 149));
      async.flushMicrotasks();
      expect(container.read(terminalBufferProvider), isEmpty);

      // Cross the threshold — line should be emitted.
      async.elapse(const Duration(milliseconds: 5));
      async.flushMicrotasks();

      final lines = container.read(terminalBufferProvider);
      expect(lines, hasLength(1));
      expect(lines.first.plainText, 'What is your name: ');
    });
  });

  test('debounces: new data within 150 ms postpones the flush', () {
    fakeAsync((async) {
      container = newContainer();
      container.read(terminalBufferProvider.notifier);

      // First packet — part of a prompt.
      fakeService.emit(TelnetDataEvent(
        Uint8List.fromList('Choose a '.codeUnits),
      ));
      async.flushMicrotasks();

      // 100 ms later, more bytes arrive — timer should reset.
      async.elapse(const Duration(milliseconds: 100));
      fakeService.emit(TelnetDataEvent(
        Uint8List.fromList('password: '.codeUnits),
      ));
      async.flushMicrotasks();

      // Another 100 ms after the second packet: still within new window.
      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();
      expect(container.read(terminalBufferProvider), isEmpty);

      // Full 150 ms after the second packet: now it should flush.
      async.elapse(const Duration(milliseconds: 60));
      async.flushMicrotasks();

      final lines = container.read(terminalBufferProvider);
      expect(lines, hasLength(1));
      expect(lines.first.plainText, 'Choose a password: ');
    });
  });

  test('does not flush when data ends with \\n (already emitted as line)', () {
    fakeAsync((async) {
      container = newContainer();
      container.read(terminalBufferProvider.notifier);

      fakeService.emit(TelnetDataEvent(
        Uint8List.fromList('You see a forest.\r\n'.codeUnits),
      ));
      async.flushMicrotasks();

      // Line arrived as a normal completed line — no pending data, timer
      // should not schedule, and we shouldn't get duplicates.
      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();

      final lines = container.read(terminalBufferProvider);
      expect(lines, hasLength(1));
      expect(lines.first.plainText, 'You see a forest.');
    });
  });

  test('suppresses flush while a partial @@…@@ prompt is arriving', () {
    fakeAsync((async) {
      container = newContainer();
      final notifier = container.read(terminalBufferProvider.notifier);
      notifier.setLoginDetected();

      // First packet: opening @@ and some digits.
      fakeService.emit(TelnetDataEvent(
        Uint8List.fromList('@@150 150 '.codeUnits),
      ));
      async.flushMicrotasks();

      // Even after 300 ms, we should NOT emit the partial prompt as a
      // visible line — the regex doesn't match yet and the @@ prefix
      // marks this as an in-flight prompt.
      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();
      expect(container.read(terminalBufferProvider), isEmpty);

      // Closing half arrives — the regex now matches, prompt is gagged,
      // no line appears in the terminal buffer.
      fakeService.emit(TelnetDataEvent(
        Uint8List.fromList('170 170 0 0@@'.codeUnits),
      ));
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      expect(container.read(terminalBufferProvider), isEmpty);
    });
  });
}

/// Minimal in-memory [MudConnectionService] for tests. Exposes an
/// [emit] helper to push [TelnetEvent]s into the notifier's listener.
class _FakeConnectionService implements MudConnectionService {
  final _events = StreamController<TelnetEvent>.broadcast();
  final _status = StreamController<ConnectionStatus>.broadcast();
  final _rawData = StreamController<Uint8List>.broadcast();
  final List<String> sentCommands = [];

  void emit(TelnetEvent event) => _events.add(event);

  @override
  Stream<TelnetEvent> get events => _events.stream;

  @override
  Stream<ConnectionStatus> get statusStream => _status.stream;

  @override
  Stream<Uint8List> get rawData => _rawData.stream;

  @override
  ConnectionStatus get status => ConnectionStatus.connected;

  @override
  bool get isConnected => true;

  @override
  ConnectionInfo? get connectionInfo => ConnectionInfo.ancientAnguish;

  @override
  Future<void> connect([ConnectionInfo? info]) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void sendCommand(String command) => sentCommands.add(command);

  @override
  void sendBytes(Uint8List bytes) {}

  @override
  Future<void> dispose() async {
    await _events.close();
    await _status.close();
    await _rawData.close();
  }
}
