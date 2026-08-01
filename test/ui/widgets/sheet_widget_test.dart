import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/core/theme/app_theme.dart';
import 'package:ancient_anguish_client/models/sheet.dart';
import 'package:ancient_anguish_client/providers/link_command_provider.dart';
import 'package:ancient_anguish_client/providers/sheet_provider.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/sheets/sheet_frame.dart';
import 'package:ancient_anguish_client/ui/widgets/terminal/sheets/sheet_widget.dart';

/// The sheet widgets, driven through the same provider path the terminal uses:
/// a sheet is registered, and the renderer is given only its id.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<int> pumpSheet(
    WidgetTester tester,
    Sheet sheet, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final id = container.read(sheetsProvider.notifier).put(sheet);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.rpgDark(),
          home: Scaffold(
            body: SingleChildScrollView(child: SheetWidget(sheetId: id)),
          ),
        ),
      ),
    );
    return id;
  }

  group('SkillsSheetWidget', () {
    final sheet = SkillsSheet(const [
      SkillEntry('Axe', 14),
      SkillEntry('Knife', 23),
      SkillEntry('Two Handed Sword', 7),
    ]);

    testWidgets('shows every skill and its rating', (tester) async {
      await pumpSheet(tester, sheet);

      expect(find.text('Axe'), findsOneWidget);
      expect(find.text('Knife'), findsOneWidget);
      expect(find.text('Two Handed Sword'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('23'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('bars are scaled to the best skill', (tester) async {
      await pumpSheet(tester, sheet);

      final factors = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((b) => b.widthFactor)
          .toList();
      // Knife is the player's best, so it fills its track.
      expect(factors, contains(1.0));
      // Axe is 14/23.
      expect(factors.any((f) => (f! - 14 / 23).abs() < 0.001), isTrue);
    });

    testWidgets('lays out on a phone without overflowing', (tester) async {
      await pumpSheet(tester, sheet, size: const Size(375, 812));
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses more columns when there is room', (tester) async {
      final many = SkillsSheet([
        for (var i = 0; i < 16; i++) SkillEntry('Skill $i', i + 1),
      ]);
      await pumpSheet(tester, many, size: const Size(375, 812));
      final narrowRows = tester.getSize(find.byType(SheetWidget)).height;

      await pumpSheet(tester, many, size: const Size(1000, 812));
      final wideRows = tester.getSize(find.byType(SheetWidget)).height;

      expect(wideRows, lessThan(narrowRows),
          reason: 'a wider sheet should need fewer rows');
      expect(tester.takeException(), isNull);
    });
  });

  group('ScoreSheetWidget', () {
    const sheet = ScoreSheet(
      fields: [
        ScoreField('Str', '16 (16)'),
        ScoreField('Race', 'Dwarf (male)'),
        ScoreField('Exp', '647,031'),
        ScoreField('Money', '7,118 coins'),
        ScoreField('Hunted by', 'No one'),
        ScoreField('Age', '5d  23h  39m  38s'),
      ],
      statuses: ['Sober', 'Thirsty', 'Hungry', 'Very encumbered'],
    );

    testWidgets('collapsed shows only the fields that move', (tester) async {
      await pumpSheet(tester, sheet);

      expect(find.text('647,031'), findsOneWidget);
      expect(find.text('7,118 coins'), findsOneWidget);
      expect(find.text('No one'), findsOneWidget);
      // The stats are the point of collapsing — they must be hidden.
      expect(find.text('16 (16)'), findsNothing);
      expect(find.text('Dwarf (male)'), findsNothing);
    });

    testWidgets('statuses are always visible', (tester) async {
      await pumpSheet(tester, sheet);
      for (final status in ['Sober', 'Thirsty', 'Hungry', 'Very encumbered']) {
        expect(find.text(status), findsOneWidget);
      }
    });

    testWidgets('tapping the header expands to the full block', (tester) async {
      final id = await pumpSheet(tester, sheet);

      await tester.tap(find.text('Score'));
      await tester.pumpAndSettle();

      expect(container.read(expandedSheetsProvider), contains(id));
      expect(find.text('16 (16)'), findsOneWidget);
      expect(find.text('Dwarf (male)'), findsOneWidget);
      expect(find.text('5d  23h  39m  38s'), findsOneWidget);
      // Still there — expanding adds, never replaces.
      expect(find.text('647,031'), findsOneWidget);
    });

    testWidgets('expansion survives a rebuild', (tester) async {
      // Expansion lives in a provider precisely because TerminalLine is
      // stateless and rebuilt on every new line of output.
      final id = await pumpSheet(tester, sheet);
      container.read(expandedSheetsProvider.notifier).toggle(id);
      await tester.pump();
      expect(find.text('Dwarf (male)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpSheet(tester, sheet);
      // A different sheet id, so this one is collapsed — the flag is per sheet.
      expect(find.text('Dwarf (male)'), findsNothing);
      expect(container.read(expandedSheetsProvider), contains(id));
    });

    testWidgets('a sheet with nothing to hide has no toggle', (tester) async {
      await pumpSheet(
        tester,
        const ScoreSheet(
          fields: [ScoreField('Exp', '1')],
          statuses: ['Sober'],
        ),
      );
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('worrying statuses are flagged, healthy ones are not',
        (tester) async {
      await pumpSheet(
        tester,
        const ScoreSheet(
          fields: [
            ScoreField('Exp', '1'),
            ScoreField('Money', '2'),
            ScoreField('Str', '3'),
            ScoreField('Dex', '4'),
          ],
          // "Unpoisoned" contains a warning word but is a good state — a
          // substring test would flag it.
          statuses: ['Unpoisoned', 'Hungry'],
        ),
      );

      // The chip is the innermost Container wrapping the label; `.first` is it,
      // since ancestors are reported nearest-first.
      Color? chipColour(String label) {
        final chip = tester.widgetList<Container>(find.ancestor(
          of: find.text(label),
          matching: find.byType(Container),
        )).first;
        return (chip.decoration as BoxDecoration?)?.color;
      }

      expect(chipColour('Hungry'), isNot(chipColour('Unpoisoned')));
    });

    testWidgets('Wimpy is one of the fields shown collapsed', (tester) async {
      await pumpSheet(
        tester,
        const ScoreSheet(
          fields: [
            ScoreField('Str', '16 (16)'),
            ScoreField('Exp', '647,031'),
            ScoreField('Wimpy', '53 hits'),
          ],
          statuses: [],
        ),
      );
      expect(find.text('Wimpy'), findsOneWidget);
      expect(find.text('53 hits'), findsOneWidget);
      expect(find.text('16 (16)'), findsNothing);
    });

    testWidgets('shows what Exp and Money did since the last score',
        (tester) async {
      // Registered through the notifier, which is what computes the delta —
      // the parser only ever sees one block.
      container.read(sheetsProvider.notifier).put(const ScoreSheet(
            fields: [
              ScoreField('Exp', '646,431'),
              ScoreField('Money', '10,118 coins'),
            ],
            statuses: [],
          ));
      await pumpSheet(
        tester,
        const ScoreSheet(
          fields: [
            ScoreField('Exp', '647,031'),
            ScoreField('Money', '7,118 coins'),
          ],
          statuses: [],
        ),
      );

      expect(find.text('+ 600'), findsOneWidget);
      expect(find.text('- 3,000'), findsOneWidget);
    });

    testWidgets('the first score of a session has nothing to compare against',
        (tester) async {
      await pumpSheet(
        tester,
        const ScoreSheet(
          fields: [ScoreField('Exp', '647,031'), ScoreField('Money', '10')],
          statuses: [],
        ),
      );
      expect(find.textContaining('+ '), findsNothing);
      expect(find.textContaining('- '), findsNothing);
    });

    testWidgets('a value that held still shows no delta', (tester) async {
      const same = ScoreSheet(
        fields: [ScoreField('Exp', '647,031'), ScoreField('Money', '10')],
        statuses: [],
      );
      container.read(sheetsProvider.notifier).put(same);
      await pumpSheet(tester, same);
      expect(find.textContaining('+ 0'), findsNothing);
    });
  });

  group('ShopListSheetWidget', () {
    const sheet = ShopListSheet(
      [
        ShopItem(count: 2, name: 'A curved knife', cost: 70),
        ShopItem(count: 2, name: 'A rusty knife', cost: 130),
        ShopItem(count: 1, name: 'A sharp knife', cost: 40),
      ],
      shown: 21,
      total: 29,
    );

    testWidgets('lists items with grouped prices', (tester) async {
      await pumpSheet(tester, sheet);

      expect(find.text('A curved knife'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
      expect(find.text('130'), findsOneWidget);
    });

    testWidgets('a count only appears when there is more than one',
        (tester) async {
      await pumpSheet(tester, sheet);
      expect(find.text('2x'), findsNWidgets(2));
      expect(find.text('1x'), findsNothing);
    });

    testWidgets('groups thousands so prices compare at a glance',
        (tester) async {
      await pumpSheet(
        tester,
        const ShopListSheet([
          ShopItem(count: 1, name: 'An iron mace', cost: 2794),
          ShopItem(count: 1, name: 'A plain sword', cost: 1397),
        ]),
      );
      expect(find.text('2,794'), findsOneWidget);
      expect(find.text('1,397'), findsOneWidget);
    });

    testWidgets('says so when the shop had more to show', (tester) async {
      await pumpSheet(tester, sheet);
      expect(find.textContaining('21 of 29'), findsOneWidget);
    });

    testWidgets('re-sorts cheapest first on request', (tester) async {
      final id = await pumpSheet(tester, sheet);

      // Shop order by default — the MUD's order is what the player asked for.
      expect(find.text('Shop order'), findsOneWidget);

      await tester.tap(find.text('Shop order'));
      await tester.pumpAndSettle();

      expect(container.read(costSortedSheetsProvider), contains(id));
      expect(find.text('Cheapest first'), findsOneWidget);

      // The cheapest row is now first in the layout.
      final sharp = tester.getRect(find.text('A sharp knife'));
      final rusty = tester.getRect(find.text('A rusty knife'));
      expect(sharp.top, lessThan(rusty.top));
    });

    testWidgets('lays out a long listing on a phone without overflowing',
        (tester) async {
      await pumpSheet(
        tester,
        ShopListSheet([
          for (var i = 0; i < 25; i++)
            ShopItem(count: 1, name: 'A very long item name $i', cost: 1000 + i),
        ]),
        size: const Size(375, 812),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an item name buys it', (tester) async {
      final sent = <String>[];
      // The buy goes through the same sender a tapped terminal link uses.
      container.dispose();
      container = ProviderContainer(overrides: [
        linkCommandSenderProvider.overrideWithValue(sent.add),
      ]);
      addTearDown(container.dispose);

      await pumpSheet(
        tester,
        const ShopListSheet([
          ShopItem(count: 1, name: 'An antique staff', cost: 900),
          ShopItem(count: 1, name: 'A dark spear', cost: 1075),
        ]),
      );

      await tester.tap(find.text('An antique staff'));
      await tester.pump();
      // The leading article is display wording, not part of the object name.
      expect(sent, ['buy antique staff']);
    });

    testWidgets('takes only the width its list needs', (tester) async {
      await pumpSheet(
        tester,
        const ShopListSheet([
          ShopItem(count: 1, name: 'A knife', cost: 40),
          ShopItem(count: 1, name: 'A club', cost: 70),
        ]),
        size: const Size(900, 600),
      );

      // The frame's own Padding still spans the terminal; the panel inside it
      // is what shrinks. Not "narrower by a hair" — a full-width panel is the
      // bug, so assert it is nowhere near 900.
      final panel = tester.getRect(find.descendant(
        of: find.byType(SheetFrame),
        matching: find.byType(IntrinsicWidth),
      ));
      expect(panel.width, lessThan(400));
      expect(panel.left, lessThan(20), reason: 'hugs the left edge');
    });

    testWidgets('a long item name still wraps inside the terminal',
        (tester) async {
      await pumpSheet(
        tester,
        const ShopListSheet([
          ShopItem(
            count: 1,
            name: 'A preposterously long ceremonial two handed greatsword of '
                'the seventh dawn',
            cost: 40,
          ),
          ShopItem(count: 1, name: 'A club', cost: 70),
        ]),
        size: const Size(375, 812),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('SheetWidget dispatch', () {
    testWidgets('an unknown id renders nothing', (tester) async {
      // A sentinel line can outlive its sheet when the buffer is cleared.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SheetWidget(sheetId: 999)),
          ),
        ),
      );
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
