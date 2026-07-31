import 'package:ancient_anguish_client/models/sheet.dart';
import 'package:ancient_anguish_client/services/parser/sheet_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sheet recognition, driven by the exact transcripts Sami supplied.
void main() {
  /// Runs [lines] through a capture the way the terminal buffer does, then
  /// flushes. Returns the sheets produced and the lines released untouched.
  ({List<Sheet> sheets, List<String> released}) run(List<String> lines) {
    final capture = SheetCapture<String>();
    final sheets = <Sheet>[];
    final released = <String>[];

    void apply(SheetCaptureResult<String> r, String plain) {
      switch (r.action) {
        case SheetCaptureAction.passThrough:
          released.add(plain);
        case SheetCaptureAction.held:
          break;
        case SheetCaptureAction.completed:
          if (r.sheet != null) sheets.add(r.sheet!);
          released.addAll(r.releasedLines);
          if (r.trailing != null) released.add(r.trailing!);
      }
    }

    for (final line in lines) {
      apply(capture.offer(line, line), line);
    }
    final flushed = capture.flush();
    if (flushed.action == SheetCaptureAction.completed) {
      if (flushed.sheet != null) sheets.add(flushed.sheet!);
      released.addAll(flushed.releasedLines);
    }
    return (sheets: sheets, released: released);
  }

  group('skills', () {
    const transcript = [
      'Your skills:',
      'Axe                   14              Polearm                4      ',
      'Club                  16              Rapier                18      ',
      'Curved Blade          12              Shortsword            16      ',
      'Exotic                 2              Spear                  7      ',
      'Flail                 14              Staff                 10      ',
      'Knife                 23              Two Handed Axe         9      ',
      'Longsword              8              Two Handed Sword       7      ',
      'Marksmanship           3              Unarmed               19',
    ];

    test('captures every skill from both columns', () {
      final result = run(transcript);
      expect(result.sheets, hasLength(1));
      final sheet = result.sheets.single as SkillsSheet;
      expect(sheet.skills, hasLength(16));
      expect(result.released, isEmpty, reason: 'the block is fully replaced');
    });

    test('reads multi-word skill names whole', () {
      final sheet = run(transcript).sheets.single as SkillsSheet;
      expect(sheet.skills, contains(const SkillEntry('Curved Blade', 12)));
      expect(sheet.skills, contains(const SkillEntry('Two Handed Axe', 9)));
      expect(sheet.skills, contains(const SkillEntry('Two Handed Sword', 7)));
    });

    test('keeps reading order — left column, then right', () {
      final sheet = run(transcript).sheets.single as SkillsSheet;
      expect(sheet.skills.first, const SkillEntry('Axe', 14));
      expect(sheet.skills[1], const SkillEntry('Polearm', 4));
      expect(sheet.skills.last, const SkillEntry('Unarmed', 19));
    });

    test('maxValue scales the bars off the real top skill', () {
      final sheet = run(transcript).sheets.single as SkillsSheet;
      expect(sheet.maxValue, 23);
    });

    test('a lone header with no rows is left as text', () {
      final result = run(['Your skills:', 'You have no weapon skills.']);
      expect(result.sheets, isEmpty);
      expect(result.released, contains('Your skills:'));
      expect(result.released, contains('You have no weapon skills.'));
    });
  });

  group('score', () {
    const transcript = [
      'Sandyclaws the fearsome yeti herder (neutral) <~ Chosen ~>',
      '',
      'Str: 16 (16)    Race : Dwarf (male)          Exp    : 647,031',
      'Dex: 13 (13)    Class: Soulbinder (18)       Wounds : none',
      'Int: 13 (13)    Guild: The Snowfolk          Money  : 7,118 coins',
      'Con: 17 (17)    Age  : 5d  23h  39m  38s     Banks  : 0 coins',
      'Wis: 16 (16)    Language: Common language    Traits : 1 points',
      '',
      'Hits : 178 (178)   Defend   : Dodge          You are: Sober',
      'Sps  :  21 (170)   Aiming at: Body           You are: Thirsty',
      'Wimpy: 53 hits     Attack   : Slash          You are: Hungry',
      'Dir  : Random      Hunted by: No one         You are: Unpoisoned',
      '                                             You are: Very encumbered',
    ];

    ScoreSheet parsed() => run(transcript).sheets.single as ScoreSheet;

    test('captures the stat block and leaves the title line as output', () {
      final result = run(transcript);
      expect(result.sheets, hasLength(1));
      // The title arrives before anything recognisable, so it stays put rather
      // than the client reaching backwards for a line it already emitted.
      expect(
        result.released,
        contains('Sandyclaws the fearsome yeti herder (neutral) <~ Chosen ~>'),
      );
    });

    test('reads a value containing double spaces without splitting it', () {
      // `Age  : 5d  23h  39m  38s` is why fields are found by label rather than
      // by splitting the line on runs of whitespace.
      expect(
        parsed().fields,
        contains(const ScoreField('Age', '5d  23h  39m  38s')),
      );
    });

    test('reads a label padded away from its own colon', () {
      // `Exp    : 647,031` — the gap inside the field is as wide as the gap
      // between fields, which is the other half of the same problem.
      expect(parsed().fields, contains(const ScoreField('Exp', '647,031')));
      expect(
        parsed().fields,
        contains(const ScoreField('Money', '7,118 coins')),
      );
    });

    test('reads two-word labels', () {
      expect(
        parsed().fields,
        contains(const ScoreField('Hunted by', 'No one')),
      );
      expect(
        parsed().fields,
        contains(const ScoreField('Aiming at', 'Body')),
      );
    });

    test('collects every You-are status', () {
      expect(parsed().statuses, [
        'Sober',
        'Thirsty',
        'Hungry',
        'Unpoisoned',
        'Very encumbered',
      ]);
    });

    test('collapsed view shows only the fields that move', () {
      final sheet = parsed();
      expect(
        sheet.frequentFields.map((f) => f.label),
        ['Exp', 'Money', 'Hunted by'],
      );
    });

    test('collapsed and expanded together lose nothing', () {
      final sheet = parsed();
      expect(
        [...sheet.frequentFields, ...sheet.restFields].length,
        sheet.fields.length,
      );
    });

    test('the stats themselves are all present', () {
      final labels = parsed().fields.map((f) => f.label).toList();
      for (final stat in ['Str', 'Dex', 'Int', 'Con', 'Wis']) {
        expect(labels, contains(stat));
      }
      expect(labels, containsAll(['Race', 'Class', 'Guild', 'Language']));
      expect(labels, containsAll(['Hits', 'Sps', 'Wimpy', 'Dir']));
    });

    test('a couple of stray colons is not a score sheet', () {
      final result = run(['Str: nonsense', 'Foo: bar']);
      expect(result.sheets, isEmpty);
    });
  });

  group('shop list', () {
    test('parses a headerless listing with a --More-- footer', () {
      final result = run(const [
        '   1  A choppingweapon..............................................   932',
        '   1  A dark spear..................................................  1075',
        '   1  An elemental orb..............................................   975',
        '   2  A gigantic nailfile...........................................    88',
        '--More--(21/29)',
      ]);
      expect(result.sheets, hasLength(1));
      final sheet = result.sheets.single as ShopListSheet;
      expect(sheet.items, hasLength(4));
      expect(
        sheet.items.first,
        const ShopItem(count: 1, name: 'A choppingweapon', cost: 932),
      );
      expect(sheet.items.last,
          const ShopItem(count: 2, name: 'A gigantic nailfile', cost: 88));
      expect(sheet.shown, 21);
      expect(sheet.total, 29);
      expect(sheet.isTruncated, isTrue);
    });

    test('parses a listing with the column header', () {
      final result = run(const [
        '#_of_ _Item_________________________________________________________ _cost_',
        '   1  A green shield................................................   800',
        '   1  A silver goblin shield........................................  1400',
        '   2  A small wooden shield.........................................   100',
      ]);
      final sheet = result.sheets.single as ShopListSheet;
      expect(sheet.items, hasLength(3));
      expect(sheet.isTruncated, isFalse);
      expect(result.released, isEmpty);
    });

    test("keeps an apostrophe in an item name", () {
      final result = run(const [
        '#_of_ _Item_________________________________________________________ _cost_',
        "   2  A fashionable knight's pack...................................   300",
        '   1  A fine bearskin pack..........................................   300',
      ]);
      final sheet = result.sheets.single as ShopListSheet;
      expect(sheet.items.first.name, "A fashionable knight's pack");
    });

    test('byCost offers the cheapest first without reordering items', () {
      final result = run(const [
        '   2  A curved knife................................................    70',
        '   2  A rusty knife.................................................   130',
        '   1  A sharp knife.................................................    40',
      ]);
      final sheet = result.sheets.single as ShopListSheet;
      expect(sheet.items.first.name, 'A curved knife');
      expect(sheet.byCost.first.name, 'A sharp knife');
      expect(sheet.byCost.last.name, 'A rusty knife');
    });

    test('a single dotted row without a header stays as text', () {
      // One row of that shape is not proof; other output produces dot leaders.
      final result = run(const [
        '   1  A green shield................................................   800',
      ]);
      expect(result.sheets, isEmpty);
      expect(result.released, hasLength(1));
    });

    test('a header plus one row is enough', () {
      final result = run(const [
        '#_of_ _Item_________________________________________________________ _cost_',
        '   1  A green shield................................................   800',
      ]);
      expect(result.sheets, hasLength(1));
    });
  });

  group('capture behaviour', () {
    test('nothing offered is ever lost when a block is rejected', () {
      const lines = [
        'Your skills:',
        'not a skill row at all',
        'You see a forest.',
      ];
      final result = run(lines);
      expect(result.sheets, isEmpty);
      expect(result.released, lines);
    });

    test('the line that ends a block is still emitted', () {
      final result = run(const [
        '#_of_ _Item_________________________________________________________ _cost_',
        '   1  A green shield................................................   800',
        'The shopkeeper eyes you.',
      ]);
      expect(result.sheets, hasLength(1));
      expect(result.released, ['The shopkeeper eyes you.']);
    });

    test('blank lines after a sheet survive as blank lines', () {
      final result = run(const [
        '#_of_ _Item_________________________________________________________ _cost_',
        '   1  A green shield................................................   800',
        '',
        '',
        '',
        'You see a forest.',
      ]);
      expect(result.sheets, hasLength(1));
      // Three blanks in, three blanks out — the sheet must not eat spacing.
      expect(result.released.where((l) => l.trim().isEmpty), hasLength(3));
      expect(result.released.last, 'You see a forest.');
    });

    test('back-to-back sheets both survive', () {
      // The line that ends one block can open the next; without re-offering it
      // the second sheet would lose its opening line and be rejected.
      final result = run(const [
        'Your skills:',
        'Axe                   14              Polearm                4',
        'Club                  16              Rapier                18',
        'Str: 16 (16)    Race : Dwarf (male)          Exp    : 647,031',
        'Dex: 13 (13)    Class: Soulbinder (18)       Wounds : none',
        'Int: 13 (13)    Guild: The Snowfolk          Money  : 7,118 coins',
        'Con: 17 (17)    Age  : 5d  23h  39m  38s     Banks  : 0 coins',
      ]);
      expect(result.sheets, hasLength(2));
      expect(result.sheets.first, isA<SkillsSheet>());
      expect(result.sheets.last, isA<ScoreSheet>());
    });

    test('a flush closes a block nothing else terminated', () {
      // A prompt arriving is what triggers this in the client; without it the
      // last block of a batch would sit in the capture unseen.
      final capture = SheetCapture<String>();
      capture.offer('Your skills:', 'Your skills:');
      capture.offer('Axe  14   Polearm  4', 'Axe  14   Polearm  4');
      expect(capture.isCapturing, isTrue);

      final flushed = capture.flush();
      expect(flushed.action, SheetCaptureAction.completed);
      expect(flushed.sheet, isA<SkillsSheet>());
      expect(capture.isCapturing, isFalse);
    });

    test('ordinary output passes straight through', () {
      final result = run(const [
        'You see a forest.',
        'The path leads east.',
        'Obvious exits: north, east and southwest.',
      ]);
      expect(result.sheets, isEmpty);
      expect(result.released, hasLength(3));
    });
  });
}
