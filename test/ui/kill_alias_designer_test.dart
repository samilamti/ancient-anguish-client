import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/settings_provider.dart';
import 'package:ancient_anguish_client/providers/text_link_rule_provider.dart';
import 'package:ancient_anguish_client/providers/trigger_provider.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';
import 'package:ancient_anguish_client/ui/screens/kill_alias_designer_screen.dart';

void main() {
  late ProviderContainer container;
  late _FakeConnectionService fakeService;

  setUp(() {
    fakeService = _FakeConnectionService();
    container = ProviderContainer(
      overrides: [
        connectionServiceProvider.overrideWithValue(fakeService),
        terminalBufferProvider.overrideWith(_FakeTerminalBufferNotifier.new),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  /// Pumps a host with a button that opens the designer for [target].
  Future<void> pumpHost(WidgetTester tester, String target) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => openKillAliasDesigner(ctx, target: target),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('save wires up alias, link rule, immersion and persists steps',
      (tester) async {
    await pumpHost(tester, 'badger');

    // One empty step row to start.
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), r'link $*');
    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'drain sp');
    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'drain dex');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    // (a) MUD-side alias was sent.
    expect(
      fakeService.sentCommands,
      contains(r'alias _k_badger do link $*,drain sp,drain dex'),
    );

    // (b) Text Link Rule.
    final tlr = container
        .read(textLinkRulesProvider)
        .firstWhere((r) => r.id == 'tlr_kill_badger');
    expect(tlr.commandTemplate, '_k_badger');
    expect(tlr.caseSensitive, isFalse);
    expect(tlr.pattern, r'\bbadger\b');
    expect(tlr.enabled, isTrue);

    // (c) Immersion (highlight trigger): red + bold.
    final trig = container
        .read(triggerRulesProvider)
        .firstWhere((r) => r.id == 'trigger_kill_badger');
    expect(trig.highlightForeground, const Color(0xFFFF0000));
    expect(trig.highlightBold, isTrue);
    expect(trig.pattern, r'\bbadger\b');

    // (d) Steps persisted.
    expect(
      container.read(settingsProvider.notifier).killAliasStepsFor('badger'),
      [r'link $*', 'drain sp', 'drain dex'],
    );
  });

  testWidgets('re-opening the designer prefills saved steps', (tester) async {
    // Seed saved steps directly.
    container
        .read(settingsProvider.notifier)
        .setKillAliasSteps('badger', [r'link $*', 'drain sp']);

    await pumpHost(tester, 'badger');

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      r'link $*',
    );
    expect(
      tester.widget<TextField>(fields.at(1)).controller!.text,
      'drain sp',
    );
  });

  testWidgets('updating an existing target reuses the same rule ids',
      (tester) async {
    await pumpHost(tester, 'badger');
    await tester.enterText(find.byType(TextField).at(0), 'kill badger');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final tlrCount = container
        .read(textLinkRulesProvider)
        .where((r) => r.id == 'tlr_kill_badger')
        .length;
    final trigCount = container
        .read(triggerRulesProvider)
        .where((r) => r.id == 'trigger_kill_badger')
        .length;
    expect(tlrCount, 1);
    expect(trigCount, 1);
  });
}

/// Fake connection that reports connected and records sent commands.
class _FakeConnectionService extends TcpConnectionService {
  final List<String> sentCommands = [];

  @override
  bool get isConnected => true;

  @override
  void sendCommand(String command) {
    sentCommands.add(command);
  }
}

/// Fake terminal buffer that skips connection-event listening.
class _FakeTerminalBufferNotifier extends TerminalBufferNotifier {
  @override
  List<StyledLine> build() => [];
}
