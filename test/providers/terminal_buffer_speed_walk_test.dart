import 'dart:typed_data';

import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/game_state_provider.dart'
    show areaDetectorProvider, promptParserProvider;
import 'package:ancient_anguish_client/providers/notification_provider.dart';
import 'package:ancient_anguish_client/providers/speed_walk_provider.dart';
import 'package:ancient_anguish_client/providers/unified_area_config_provider.dart';
import 'package:ancient_anguish_client/protocol/telnet/telnet_events.dart';
import 'package:ancient_anguish_client/services/area/area_detector.dart';
import 'package:ancient_anguish_client/services/config/unified_area_config_manager.dart';
import 'package:ancient_anguish_client/services/parser/prompt_parser.dart';
import 'package:ancient_anguish_client/services/speedwalk/speed_walk.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection_service.dart';

/// Speed walking hides the rooms on the way and shows the target room.
void main() {
  late FakeConnectionService service;
  late ProviderContainer c;

  setUp(() {
    service = FakeConnectionService();
    c = ProviderContainer(overrides: [
      connectionServiceProvider.overrideWithValue(service),
      promptParserProvider.overrideWithValue(PromptParser()),
      areaDetectorProvider.overrideWith((ref) => Future.value(AreaDetector())),
      unifiedAreaConfigProvider
          .overrideWith((ref) => Future.value(UnifiedAreaConfigManager())),
    ]);
    addTearDown(c.dispose);
    c.read(terminalBufferProvider.notifier);
  });

  void feed(Iterable<String> lines) => service.emit(TelnetDataEvent(
        Uint8List.fromList('${lines.join('\r\n')}\r\n'.codeUnits),
      ));

  List<String> shown() =>
      [for (final l in c.read(terminalBufferProvider)) l.plainText];

  test('rooms on the way are hidden, the target room is shown', () {
    fakeAsync((async) {
      c.read(speedWalkProvider.notifier).begin(SpeedWalkPath.parse('2ne')!);
      feed([
        'Road (n,s)',
        'A dusty road.',
        'Road (n,s)',
        'Still dusty.',
        'Market square (w,e)',
        'A busy market.',
      ]);
      async.flushMicrotasks();
      final text = shown();
      expect(text, isNot(contains('A dusty road.')));
      expect(text, isNot(contains('Still dusty.')));
      expect(text, containsAllInOrder(['Market square (w,e)', 'A busy market.']));
      expect(c.read(speedWalkProvider), isFalse);
    });
  });

  test('two refusals abort and show the output again', () {
    fakeAsync((async) {
      c.read(speedWalkProvider.notifier).begin(SpeedWalkPath.parse('5n')!);
      feed(['Road (n,s)', 'What?', "There's no such exit.", 'Later line.']);
      async.flushMicrotasks();
      expect(shown(), isNot(contains('Road (n,s)')));
      expect(shown(), containsAllInOrder(["There's no such exit.", 'Later line.']));
      expect(c.read(speedWalkProvider), isFalse);
      expect(c.read(appNotificationsProvider).single.message,
          contains('refused'));
    });
  });

  test('parsing resumes after three seconds whatever happens', () {
    fakeAsync((async) {
      c.read(speedWalkProvider.notifier).begin(SpeedWalkPath.parse('3n')!);
      feed(['Road (n,s)']);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      expect(c.read(speedWalkProvider), isFalse);
      feed(['You are back.']);
      async.flushMicrotasks();
      expect(shown(), contains('You are back.'));
      expect(shown(), isNot(contains('Road (n,s)')));
    });
  });
}
