import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/local_features_provider.dart';
import 'package:ancient_anguish_client/providers/play_mode_provider.dart';
import 'package:ancient_anguish_client/providers/room_targets_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/providers/target_provider.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/input_bar.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/play_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectionService extends TcpConnectionService {
  final List<String> sent = [];

  @override
  bool get isConnected => true;

  @override
  void sendCommand(String command) => sent.add(command);
}

void main() {
  late _FakeConnectionService service;
  late List<int> slots;

  Future<ProviderContainer> pumpPlay(
    WidgetTester tester, {
    Size size = const Size(1200, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    service = _FakeConnectionService();
    slots = [];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        connectionServiceProvider.overrideWithValue(service),
        localFeaturesAvailableProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => PlayModeKeys(
              available: MediaQuery.of(context).size.width >= 768,
              onSlot: (_, slot) => slots.add(slot),
              child: const Column(
                children: [Expanded(child: SizedBox()), InputBar()],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(InputBar)));
    container.read(playModeProvider.notifier).setEnabled(true);
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('the strip replaces the input and holds focus', (tester) async {
    final container = await pumpPlay(tester);
    expect(find.text(PlayModeStrip.text), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(container.read(playModeFocusProvider).hasPrimaryFocus, isTrue);
  });

  testWidgets('WASD, diagonals and R/F move with full words', (tester) async {
    await pumpPlay(tester);
    for (final k in [
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyQ,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyZ,
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.keyF,
    ]) {
      await tester.sendKeyEvent(k);
    }
    expect(service.sent, [
      'north', 'west', 'south', 'east', 'northwest', 'northeast',
      'southwest', 'southeast', 'up', 'down',
    ]);
  });

  testWidgets('a held movement key keeps walking', (tester) async {
    await pumpPlay(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(service.sent, ['north', 'north', 'north']);
  });

  testWidgets('digits fire slots 1-10, held digits fire once', (tester) async {
    await pumpPlay(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit3);
    expect(slots, [0, 9, 2]);
    expect(service.sent, isEmpty);
  });

  testWidgets('Ctrl/Cmd chords are left for the global shortcuts',
      (tester) async {
    await pumpPlay(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(service.sent, isEmpty);
    expect(slots, isEmpty);
  });

  testWidgets('Tab cycles, X ignores, Esc clears', (tester) async {
    final container = await pumpPlay(tester);
    final rooms = container.read(roomTargetsProvider.notifier);
    container.read(targetProvider);
    for (final l in ['Forest (n)', 'An orc.', 'A wild boar.', 'An orc.', '']) {
      rooms.processLine(l);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(container.read(targetProvider), 'orc');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(container.read(targetProvider), 'orc 2');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(container.read(targetProvider), 'orc');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    expect(container.read(settingsProvider).ignoredKillTargets, ['orc']);
    expect(container.read(targetProvider), 'boar');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(container.read(targetProvider), isNull);
    // Let the Undo notification time out.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });

  testWidgets('Enter opens the input; sending closes it again',
      (tester) async {
    final container = await pumpPlay(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(container.read(playModeProvider), PlayMode.input);
    expect(container.read(inputFocusProvider).hasFocus, isTrue);

    // Letters type now, they don't move.
    await tester.enterText(find.byType(TextField), 'say hi');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(service.sent, ['say hi']);
    expect(container.read(playModeProvider), PlayMode.play);
    expect(find.text(PlayModeStrip.text), findsOneWidget);
    expect(container.read(playModeFocusProvider).hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    expect(service.sent, ['say hi', 'north']);
  });

  testWidgets('Esc or Enter on an empty input closes it without sending',
      (tester) async {
    final container = await pumpPlay(tester);
    for (final key in [LogicalKeyboardKey.escape, LogicalKeyboardKey.enter]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(container.read(playModeProvider), PlayMode.input);
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(container.read(playModeProvider), PlayMode.play);
    }
    expect(service.sent, isEmpty);
  });

  testWidgets('other letters send nothing', (tester) async {
    await pumpPlay(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump(const Duration(seconds: 1));
    expect(service.sent, isEmpty);
  });

  testWidgets('phones never get play mode', (tester) async {
    final container = await pumpPlay(tester, size: const Size(400, 800));
    expect(find.text(PlayModeStrip.text), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(container.read(playModeFocusProvider).hasFocus, isFalse);
  });
}
