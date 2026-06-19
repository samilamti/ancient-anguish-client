import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/providers/reply_request_provider.dart';
import 'package:ancient_anguish_client/ui/widgets/social/social_input_bar.dart';
import 'package:ancient_anguish_client/ui/widgets/social/social_message_list.dart';

/// Returns the Tells recipient ("name") field's current text.
String _nameFieldText(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'name',
    ),
  );
  return field.controller!.text;
}

void main() {
  group('ReplyRequestNotifier', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('starts null', () {
      expect(container.read(replyRequestProvider), isNull);
    });

    test('reply() carries the recipient and bumps the sequence', () {
      final notifier = container.read(replyRequestProvider.notifier);

      notifier.reply('Gandalf');
      final first = container.read(replyRequestProvider)!;
      expect(first.recipient, 'Gandalf');
      expect(first.seq, 1);

      // Re-firing for the same partner still advances seq so consumers react.
      notifier.reply('Gandalf');
      final second = container.read(replyRequestProvider)!;
      expect(second.recipient, 'Gandalf');
      expect(second.seq, 2);

      notifier.reply(null);
      final third = container.read(replyRequestProvider)!;
      expect(third.recipient, isNull);
      expect(third.seq, 3);
    });
  });

  group('SocialInputBar (Tells) reply signal', () {
    Future<ProviderContainer> pumpTellsBar(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SocialInputBar(type: SocialListType.tells),
            ),
          ),
        ),
      );
      return container;
    }

    testWidgets('pre-fills the recipient name from the reply signal',
        (tester) async {
      final container = await pumpTellsBar(tester);
      expect(_nameFieldText(tester), isEmpty);

      container.read(replyRequestProvider.notifier).reply('Gandalf');
      await tester.pump();

      expect(_nameFieldText(tester), 'Gandalf');
    });

    testWidgets('overwrites a stale recipient (force, not only-when-empty)',
        (tester) async {
      final container = await pumpTellsBar(tester);
      final notifier = container.read(replyRequestProvider.notifier);

      notifier.reply('OldPartner');
      await tester.pump();
      expect(_nameFieldText(tester), 'OldPartner');

      // The plain auto-populate only fills an empty field; the reply signal
      // must override the existing (now stale) recipient.
      notifier.reply('NewPartner');
      await tester.pump();
      expect(_nameFieldText(tester), 'NewPartner');
    });

    testWidgets('a null recipient leaves the name field untouched',
        (tester) async {
      final container = await pumpTellsBar(tester);
      final notifier = container.read(replyRequestProvider.notifier);

      notifier.reply('Frodo');
      await tester.pump();
      expect(_nameFieldText(tester), 'Frodo');

      notifier.reply(null);
      await tester.pump();
      expect(_nameFieldText(tester), 'Frodo');
    });
  });
}
