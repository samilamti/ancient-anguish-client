import 'package:ancient_anguish_client/models/quick_command.dart';
import 'package:ancient_anguish_client/providers/connection_provider.dart';
import 'package:ancient_anguish_client/providers/target_provider.dart';
import 'package:ancient_anguish_client/services/connection/connection_service.dart';
import 'package:ancient_anguish_client/ui/widgets/mobile/quick_command_runner.dart';
import 'package:flutter/material.dart';
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
  testWidgets('choosing a creature in the Kill picker sets the target',
      (tester) async {
    final service = _FakeConnectionService();
    await tester.pumpWidget(ProviderScope(
      overrides: [connectionServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () =>
                  runQuickCommand(context, ref, QuickCommand.defaults.first),
              child: const Text('Kill'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Kill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('bird'));
    await tester.pumpAndSettle();

    expect(service.sent, ['kill bird']);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(TextButton)));
    expect(container.read(targetProvider), 'bird');
  });
}
