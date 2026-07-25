import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/recent_words_provider.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/input_bar.dart';

void main() {
  late _FakeConnectionService service;

  Future<ProviderContainer> pumpInputBar(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    service = _FakeConnectionService();
    final container = ProviderContainer(
      overrides: [connectionServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: InputBar()),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  group('InputBar mobile Hints', () {
    testWidgets('a partial-template hint fills the input instead of sending',
        (tester) async {
      await pumpInputBar(tester, size: const Size(400, 800));

      await tester.enterText(find.byType(TextField), 'dot');
      await tester.pump();

      // The chip shows the completion (trailing space trimmed for display).
      expect(find.text('dotimes 30'), findsOneWidget);

      await tester.tap(find.text('dotimes 30'));
      await tester.pump();

      // The full completion — including the trailing space — fills the input,
      // and nothing was sent: the user still has to name the repeated command.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'dotimes 30 ');
      expect(service.sentCommands, isEmpty);

      // Once typed past the trigger, the suggestion clears.
      expect(find.text('dotimes 30'), findsNothing);
    });

    testWidgets('a complete rule hint fires straight at the MUD on tap',
        (tester) async {
      await pumpInputBar(tester, size: const Size(400, 800));

      await tester.enterText(find.byType(TextField), 'po');
      await tester.pump();
      expect(find.text('powerup'), findsOneWidget);

      await tester.tap(find.text('powerup'));
      await tester.pump();

      expect(service.sentCommands, ['powerup']);
    });

    testWidgets('recent MUD words complete the word being typed and send',
        (tester) async {
      final container = await pumpInputBar(tester, size: const Size(400, 800));
      container
          .read(recentWordsProvider.notifier)
          .extractFromLine('A large goblin guards the trunk.');
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'kill gob');
      await tester.pump();
      expect(find.text('goblin'), findsOneWidget);

      await tester.tap(find.text('goblin'));
      await tester.pump();

      expect(service.sentCommands, ['kill goblin']);
    });

    testWidgets('no hints on desktop widths — TAB drives completion there',
        (tester) async {
      final container = await pumpInputBar(tester, size: const Size(1200, 800));
      container
          .read(recentWordsProvider.notifier)
          .extractFromLine('A large goblin appears.');
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'dot');
      await tester.pump();
      expect(find.text('dotimes 30'), findsNothing);

      await tester.enterText(find.byType(TextField), 'kill gob');
      await tester.pump();
      expect(find.text('goblin'), findsNothing);
    });
  });
}

class _FakeConnectionService extends TcpConnectionService {
  final List<String> sentCommands = [];

  @override
  bool get isConnected => true;

  @override
  void sendCommand(String command) {
    sentCommands.add(command);
  }
}
