import 'package:ancient_anguish_client/ui/screens/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('About lists the play-mode keys', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => {
        'appName': 'AA',
        'packageName': 'aa',
        'version': '0.0.0',
        'buildNumber': '1',
      },
    );
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AboutScreen())));
    await tester.pump();
    expect(find.text('In play mode'), findsOneWidget);
    expect(find.text('W A S D'), findsOneWidget);
    expect(find.textContaining('Play mode on/off'), findsOneWidget);
    expect(find.text('Clear the target'), findsOneWidget);
  });
}
