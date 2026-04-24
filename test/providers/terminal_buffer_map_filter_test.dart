import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/connection_info.dart';
import 'package:ancient_anguish_client/protocol/telnet/telnet_events.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/framed_text_block_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart';
import 'package:ancient_anguish_client/providers/map_block_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/connection/connection_interface.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';

/// End-to-end detection tests for the emoji-maps pipeline.
///
/// Feeds raw bytes into a [TerminalBufferNotifier] with `emojiMapsEnabled`
/// on, and asserts that:
/// - a real map block emits a map sentinel (grid widget path), and
/// - a non-map framed block (shop listing) emits a framed sentinel
///   (parchment widget path), with frame chars stripped from the stored
///   [FramedTextBlock].
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
    container = newContainer();
    // Enable emoji maps so the detection pipeline engages.
    container
        .read(settingsProvider.notifier)
        .loadFromJson({'emojiMapsEnabled': true});
    // Attach the notifier so it starts listening.
    container.read(terminalBufferProvider.notifier);
  });

  tearDown(() => container.dispose());

  Future<void> feed(String text) async {
    fakeService.emit(
      TelnetDataEvent(Uint8List.fromList(text.codeUnits)),
    );
    // Let the stream listener run.
    await Future.microtask(() {});
    await Future.microtask(() {});
  }

  test('real map block emits a map sentinel, not a framed sentinel', () async {
    // Border regex requires 20+ dashes.
    const mapStream =
        '+------------------------+\r\n'
        '| /\\ oo OO ~~ == :: ## |\r\n'
        '| == +|<[]>== OO ~~ oo |\r\n'
        '| ~~ == :: /\\ oo OO ## |\r\n'
        '+------------------------+\r\n';

    await feed(mapStream);

    final lines = container.read(terminalBufferProvider);
    expect(lines, hasLength(1));
    final plain = lines.first.plainText;

    expect(tryParseBlockId(plain), isNotNull,
        reason: 'Expected a map sentinel for a real map block.');
    expect(tryParseFramedBlockId(plain), isNull);

    expect(container.read(mapBlocksProvider), hasLength(1));
    expect(container.read(framedTextBlocksProvider), isEmpty);
  });

  test('shop listing emits a framed sentinel with frame chars stripped',
      () async {
    const shopStream =
        '+----------------------------------------+\r\n'
        '|                                        |\r\n'
        '| We sell only the best throwing weapons |\r\n'
        '|                                        |\r\n'
        '|     a dart.....................94      |\r\n'
        '|     a throwing knife..........536      |\r\n'
        '|     a hunga-munga............1700      |\r\n'
        '|                                        |\r\n'
        '+----------------------------------------+\r\n';

    await feed(shopStream);

    final lines = container.read(terminalBufferProvider);
    expect(lines, hasLength(1),
        reason: 'Whole block should collapse to a single sentinel line.');
    final plain = lines.first.plainText;

    expect(tryParseFramedBlockId(plain), isNotNull,
        reason: 'Expected a framed sentinel for a shop listing.');
    expect(tryParseBlockId(plain), isNull);

    expect(container.read(mapBlocksProvider), isEmpty);
    final framed = container.read(framedTextBlocksProvider);
    expect(framed, hasLength(1));

    // Frame chars are stripped; content is preserved.
    final block = framed.values.first;
    expect(block.lineCount, 7); // 7 interior rows between the two borders.
    expect(block.lines[1].plainText, ' We sell only the best throwing weapons ');
    expect(block.lines[3].plainText, '     a dart.....................94      ');
    // No `+---+` borders should have leaked in.
    for (final l in block.lines) {
      expect(l.plainText.contains('+---'), isFalse);
    }
  });

  test('degenerate `+---+\\n+---+` block with no interior is dropped',
      () async {
    const emptyStream =
        '+----------------------------------------+\r\n'
        '+----------------------------------------+\r\n';

    await feed(emptyStream);

    expect(container.read(terminalBufferProvider), isEmpty);
    expect(container.read(mapBlocksProvider), isEmpty);
    expect(container.read(framedTextBlocksProvider), isEmpty);
  });
}

class _FakeConnectionService implements MudConnectionService {
  final _events = StreamController<TelnetEvent>.broadcast();
  final _status = StreamController<ConnectionStatus>.broadcast();
  final _rawData = StreamController<Uint8List>.broadcast();

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
  void sendCommand(String command) {}

  @override
  void sendBytes(Uint8List bytes) {}

  @override
  Future<void> dispose() async {
    await _events.close();
    await _status.close();
    await _rawData.close();
  }
}
