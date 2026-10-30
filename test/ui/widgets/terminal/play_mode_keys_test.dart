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
              onSlot: (_, slot) {
                slots.add(slot);
                return slot == 0 ? const ['bow', 'smile'] : const [];
              },
              child: const Column(
                children: [Expanded(child: PlayKeyOverlay()), InputBar()],
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

  testWidgets('the overlay shows the key and what it sent, then fades',
      (tester) async {
    await pumpPlay(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    expect(find.text('W'), findsOneWidget);
    expect(find.text('north'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('bow; smile'), findsOneWidget);

    await tester.pump(PlayKeyOverlay.duration);
    final opacity = tester.widget<Opacity>(find.ancestor(
        of: find.text('bow; smile'), matching: find.byType(Opacity)));
    expect(opacity.opacity, 0);
  });

  testWidgets('an empty slot shows nothing', (tester) async {
    await pumpPlay(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    expect(find.text('2'), findsNothing);
  });

  testWidgets('the overlay stays away when switched off in settings',
      (tester) async {
    final container = await pumpPlay(tester);
    container.read(settingsProvider.notifier).setPlayModeKeyOverlay(false);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    expect(service.sent, ['north']);
    expect(find.text('north'), findsNothing);
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

  group('typed commands fill the action bar', () {
    Future<void> type(WidgetTester tester, String line) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(TextField), line);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('each new command takes the next free slot', (tester) async {
      final container = await pumpPlay(tester);
      container.read(settingsProvider.notifier).setActionBarSlot(1, 'alias_sc');
      await type(tester, 'kill orc');
      await type(tester, 'kill orc'); // already on the bar
      await type(tester, 'north'); // movement has its own keys
      await type(tester, 'sc'); // already on the bar as slot 2's alias
      await type(tester, 'drink potion');
      final s = container.read(settingsProvider);
      expect(s.actionBarCommands.take(3), ['kill orc', null, 'drink potion']);
      expect(s.actionBarAliasIds[1], 'alias_sc');
    });

    testWidgets('nothing is added outside play mode', (tester) async {
      final container = await pumpPlay(tester);
      container.read(playModeProvider.notifier).setEnabled(false);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'kill orc');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(container.read(settingsProvider).actionBarCommands,
          everyElement(isNull));
    });
  });

  group('autoAddActionBarCommand', () {
    test('stops once all ten slots are taken', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final s = c.read(settingsProvider.notifier);
      s.setActionBarSlot(4, 'mine');
      for (var i = 0; i < 9; i++) {
        expect(s.autoAddActionBarCommand('cmd $i'), isNotNull);
      }
      expect(s.autoAddActionBarCommand('one too many'), isNull);
      final bar = c.read(settingsProvider);
      expect(bar.actionBarAliasIds[4], 'mine');
      expect(bar.actionBarCommands[4], isNull);
      expect(bar.actionBarCommands.whereType<String>(), hasLength(9));
    });

    test('assigning or clearing a slot replaces its command', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final s = c.read(settingsProvider.notifier);
      s.autoAddActionBarCommand('kill orc');
      s.setActionBarSlot(0, null);
      expect(c.read(settingsProvider).actionBarCommands[0], isNull);
      // The freed slot is filled again by the next typed command.
      expect(s.autoAddActionBarCommand('kill orc'), 0);
    });

    test('commands round-trip through settings.json', () {
      final json = const AppSettings().copyWith(actionBarCommands: [
        'kill orc', null, null, null, null, null, null, null, null, null,
      ]).toJson();
      expect(AppSettings.fromJson(json).actionBarCommands.first, 'kill orc');
    });
  });

  group('T', () {
    testWidgets('kills the target', (tester) async {
      final container = await pumpPlay(tester);
      container.read(targetProvider.notifier).set('orc 2');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      expect(service.sent, ['kill orc 2']);
    });

    testWidgets('held T kills once', (tester) async {
      final container = await pumpPlay(tester);
      container.read(targetProvider.notifier).set('orc');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyT);
      expect(service.sent, ['kill orc']);
    });

    testWidgets('with no target sends nothing and says so', (tester) async {
      final container = await pumpPlay(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      expect(service.sent, isEmpty);
      expect(container.read(terminalBufferProvider).last.plainText,
          'No target.');
    });

    testWidgets('Shift+T ignores the target instead', (tester) async {
      final container = await pumpPlay(tester);
      container.read(targetProvider.notifier).set('orc');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(service.sent, isEmpty);
      expect(container.read(settingsProvider).ignoredKillTargets, ['orc']);
      expect(container.read(targetProvider), isNull);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    });
  });
}
