import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/alias_rule.dart';
import 'package:ancient_anguish_client/models/trigger_rule.dart';
import 'package:ancient_anguish_client/services/config/markdown_config_parser.dart';

void main() {
  group('MarkdownConfigParser — immersions', () {
    test('parses highlights with all properties', () {
      const md = '''
# Highlights

## 01 - Battle Vitals
Pattern: `HP:\\s+(\\d+)\\s+SP:\\s+(\\d+)`
Foreground: #FF5555
Background: #330000
Bold: true
Whole Line: true
''';
      final rules = MarkdownConfigParser.parseImmersions(md);
      expect(rules, hasLength(1));
      final r = rules.first;
      expect(r.id, 'hl_01');
      expect(r.name, 'Battle Vitals');
      expect(r.pattern, r'HP:\s+(\d+)\s+SP:\s+(\d+)');
      expect(r.enabled, true);
      expect(r.action, TriggerAction.highlight);
      expect(r.highlightForeground, const Color(0xFFFF5555));
      expect(r.highlightBackground, const Color(0xFF330000));
      expect(r.highlightBold, true);
      expect(r.highlightWholeLine, true);
    });

    test('parses multiple sections', () {
      const md = '''
# Highlights

## 01 - Tells
Pattern: `\\w+ tells you:`
Foreground: #00FF00
Bold: true

## 02 - Attacks
Pattern: `attacks you`
Foreground: #FF0000

# Sounds

## 01 - Tell notification
Pattern: `\\w+ tells you:`
Sound: C:/sounds/tell.mp3

# Gags

`spam pattern`
`more spam`
''';
      final rules = MarkdownConfigParser.parseImmersions(md);
      expect(rules, hasLength(5));

      // Highlights.
      expect(rules[0].name, 'Tells');
      expect(rules[0].action, TriggerAction.highlight);
      expect(rules[0].highlightForeground, const Color(0xFF00FF00));
      expect(rules[0].highlightBold, true);
      expect(rules[1].name, 'Attacks');
      expect(rules[1].action, TriggerAction.highlight);

      // Sounds.
      expect(rules[2].name, 'Tell notification');
      expect(rules[2].action, TriggerAction.playSound);
      expect(rules[2].soundPath, 'C:/sounds/tell.mp3');

      // Gags.
      expect(rules[3].action, TriggerAction.gag);
      expect(rules[3].pattern, 'spam pattern');
      expect(rules[4].action, TriggerAction.gag);
      expect(rules[4].pattern, 'more spam');
    });

    test('parses disabled entries', () {
      const md = '''
# Highlights

## 01 - Active rule
Pattern: `active`
Foreground: #00FF00

## 02 - Disabled rule (disabled)
Pattern: `disabled`
Foreground: #FF0000
''';
      final rules = MarkdownConfigParser.parseImmersions(md);
      expect(rules, hasLength(2));
      expect(rules[0].enabled, true);
      expect(rules[0].name, 'Active rule');
      expect(rules[1].enabled, false);
      expect(rules[1].name, 'Disabled rule');
    });

    test('parses empty content', () {
      final rules = MarkdownConfigParser.parseImmersions('');
      expect(rules, isEmpty);
    });

    test('parses gags-only file', () {
      const md = '''
# Gags

`birds chirping`
`ice cream pattern`
''';
      final rules = MarkdownConfigParser.parseImmersions(md);
      expect(rules, hasLength(2));
      expect(rules[0].id, 'gag_0');
      expect(rules[0].pattern, 'birds chirping');
      expect(rules[0].action, TriggerAction.gag);
      expect(rules[1].id, 'gag_1');
      expect(rules[1].pattern, 'ice cream pattern');
    });

    test('round-trips highlights through serialize/parse', () {
      final original = [
        TriggerRule(
          id: 'hl_01',
          name: 'Test Trigger',
          pattern: r'hello\s+world',
          action: TriggerAction.highlight,
          highlightForeground: const Color(0xFF00FF00),
          highlightBackground: const Color(0xFFCC0000),
          highlightBold: true,
          highlightWholeLine: true,
        ),
        TriggerRule(
          id: 'snd_01',
          name: 'Sound Only',
          pattern: r'beep',
          action: TriggerAction.playSound,
          soundPath: '/sounds/beep.mp3',
        ),
      ];

      final md = MarkdownConfigParser.serializeImmersions(original);
      final parsed = MarkdownConfigParser.parseImmersions(md);

      expect(parsed, hasLength(2));
      expect(parsed[0].name, 'Test Trigger');
      expect(parsed[0].pattern, original[0].pattern);
      expect(parsed[0].action, TriggerAction.highlight);
      expect(parsed[0].highlightForeground, const Color(0xFF00FF00));
      expect(parsed[0].highlightBackground, const Color(0xFFCC0000));
      expect(parsed[0].highlightBold, true);
      expect(parsed[0].highlightWholeLine, true);

      expect(parsed[1].action, TriggerAction.playSound);
      expect(parsed[1].soundPath, '/sounds/beep.mp3');
    });

    test('round-trips gags through serialize/parse', () {
      final original = [
        TriggerRule(
          id: 'gag_0',
          name: 'Gag 1',
          pattern: 'spam',
          action: TriggerAction.gag,
        ),
        TriggerRule(
          id: 'gag_1',
          name: 'Gag 2',
          pattern: 'noise',
          action: TriggerAction.gag,
        ),
      ];

      final md = MarkdownConfigParser.serializeImmersions(original);
      final parsed = MarkdownConfigParser.parseImmersions(md);

      expect(parsed, hasLength(2));
      expect(parsed[0].pattern, 'spam');
      expect(parsed[0].action, TriggerAction.gag);
      expect(parsed[1].pattern, 'noise');
    });

    test('splits highlightAndSound into both sections', () {
      final original = [
        TriggerRule(
          id: 'trig_1',
          name: 'Combined',
          pattern: r'\w+ tells you:',
          action: TriggerAction.highlightAndSound,
          highlightForeground: const Color(0xFF00FF00),
          soundPath: '/sounds/tell.mp3',
        ),
      ];

      final md = MarkdownConfigParser.serializeImmersions(original);
      expect(md, contains('# Highlights'));
      expect(md, contains('# Sounds'));
      expect(md, contains('Foreground: #00FF00'));
      expect(md, contains('Sound: /sounds/tell.mp3'));

      // Parsing produces two separate rules.
      final parsed = MarkdownConfigParser.parseImmersions(md);
      expect(parsed, hasLength(2));
      expect(parsed[0].action, TriggerAction.highlight);
      expect(parsed[1].action, TriggerAction.playSound);
    });

    test('omits empty sections', () {
      final original = [
        TriggerRule(
          id: 'gag_0',
          name: 'Gag 1',
          pattern: 'spam',
          action: TriggerAction.gag,
        ),
      ];

      final md = MarkdownConfigParser.serializeImmersions(original);
      expect(md, isNot(contains('# Highlights')));
      expect(md, isNot(contains('# Sounds')));
      expect(md, contains('# Gags'));
    });

    test('only writes non-default highlight properties', () {
      final original = [
        TriggerRule(
          id: 'hl_01',
          name: 'Minimal',
          pattern: 'test',
          action: TriggerAction.highlight,
          // No foreground/background, bold=false, wholeLine=false.
        ),
      ];

      final md = MarkdownConfigParser.serializeImmersions(original);
      expect(md, isNot(contains('Foreground:')));
      expect(md, isNot(contains('Background:')));
      expect(md, isNot(contains('Bold:')));
      expect(md, isNot(contains('Whole Line:')));
    });
  });

  group('MarkdownConfigParser — aliases', () {
    test('parses aliases with comments', () {
      const md = '''
# 01 - ga
Expansion: get all
Comments: Get all items from the ground
''';
      final rules = MarkdownConfigParser.parseAliases(md);
      expect(rules, hasLength(1));
      expect(rules[0].id, 'alias_01');
      expect(rules[0].keyword, 'ga');
      expect(rules[0].expansion, 'get all');
      expect(rules[0].enabled, true);
      expect(rules[0].description, 'Get all items from the ground');
    });

    test('parses disabled alias', () {
      const md = '''
# 01 - old (disabled)
Expansion: something
''';
      final rules = MarkdownConfigParser.parseAliases(md);
      expect(rules, hasLength(1));
      expect(rules[0].keyword, 'old');
      expect(rules[0].enabled, false);
    });

    test('parses alias without comments', () {
      const md = '''
# 01 - k
Expansion: kill \$1
''';
      final rules = MarkdownConfigParser.parseAliases(md);
      expect(rules, hasLength(1));
      expect(rules[0].keyword, 'k');
      expect(rules[0].expansion, r'kill $1');
      expect(rules[0].description, isNull);
    });

    test('round-trips aliases through serialize/parse', () {
      final original = [
        const AliasRule(
          id: 'alias_01',
          keyword: 'k',
          expansion: r'kill $1',
          description: 'Kill target',
        ),
        const AliasRule(
          id: 'alias_02',
          keyword: 'buff',
          expansion: 'cast str;cast dex',
          enabled: false,
        ),
      ];

      final md = MarkdownConfigParser.serializeAliases(original);
      final parsed = MarkdownConfigParser.parseAliases(md);

      expect(parsed, hasLength(2));
      expect(parsed[0].keyword, 'k');
      expect(parsed[0].expansion, r'kill $1');
      expect(parsed[0].description, 'Kill target');
      expect(parsed[0].enabled, true);
      expect(parsed[1].keyword, 'buff');
      expect(parsed[1].enabled, false);
      expect(parsed[1].description, isNull);
    });

    test('parses empty content', () {
      final rules = MarkdownConfigParser.parseAliases('');
      expect(rules, isEmpty);
    });
  });

  group('MarkdownConfigParser — legacy triggers', () {
    test('parses old bold-property format', () {
      const md = '''
# Triggers

## Tell
- **Pattern:** `\\w+ tells you:`
- **Action:** highlightAndSound
- **Sound:** C:/sounds/tell.mp3
- **Highlight Foreground:** #00FF00

## Gag Spam
- **Pattern:** `^\\*\\*\\* .+ has`
- **Action:** gag
- **Enabled:** false
''';
      final rules = MarkdownConfigParser.parseLegacyTriggers(md);
      expect(rules, hasLength(2));
      expect(rules[0].name, 'Tell');
      expect(rules[0].action, TriggerAction.highlightAndSound);
      expect(rules[0].soundPath, 'C:/sounds/tell.mp3');
      expect(rules[0].highlightForeground, const Color(0xFF00FF00));
      expect(rules[1].name, 'Gag Spam');
      expect(rules[1].action, TriggerAction.gag);
      expect(rules[1].enabled, false);
    });

    test('migration: legacy triggers serialize to immersions format', () {
      const legacyMd = '''
## Tells
- **Id:** trig_tells
- **Pattern:** `\\w+ tells you:`
- **Action:** highlight
- **Highlight Foreground:** #00FF00
- **Highlight Bold:** true
''';
      final rules = MarkdownConfigParser.parseLegacyTriggers(legacyMd);
      final newMd = MarkdownConfigParser.serializeImmersions(rules);
      expect(newMd, contains('# Highlights'));
      expect(newMd, contains('## 01 - Tells'));
      expect(newMd, contains('Pattern: `'));
      expect(newMd, contains('Foreground: #00FF00'));
      expect(newMd, contains('Bold: true'));
    });
  });

  group('MarkdownConfigParser — legacy aliases', () {
    test('parses old bold-property format', () {
      const md = '''
# Aliases

## Get All
- **Id:** alias_ga
- **Keyword:** ga
- **Expansion:** get all
- **Enabled:** true
- **Description:** Get all items from the ground
''';
      final rules = MarkdownConfigParser.parseLegacyAliases(md);
      expect(rules, hasLength(1));
      expect(rules[0].id, 'alias_ga');
      expect(rules[0].keyword, 'ga');
      expect(rules[0].expansion, 'get all');
      expect(rules[0].description, 'Get all items from the ground');
    });

    test('migration: legacy aliases serialize to new format', () {
      const legacyMd = '''
## k
- **Keyword:** k
- **Expansion:** kill \$1
- **Description:** Kill target
''';
      final rules = MarkdownConfigParser.parseLegacyAliases(legacyMd);
      final newMd = MarkdownConfigParser.serializeAliases(rules);
      expect(newMd, contains('# 01 - k'));
      expect(newMd, contains('Expansion: kill \$1'));
      expect(newMd, contains('Comments: Kill target'));
    });
  });

  group('MarkdownConfigParser — area table', () {
    test('parses a two-column table', () {
      const md = '''
# Area Images

| Area | Image |
|---|---|
| Tantallon | C:/images/castle.png |
| Thief Forest | C:/images/forest.jpg |
''';
      final map = MarkdownConfigParser.parseAreaTable(md);
      expect(map, hasLength(2));
      expect(map['Tantallon'], 'C:/images/castle.png');
      expect(map['Thief Forest'], 'C:/images/forest.jpg');
    });

    test('round-trips area table through serialize/parse', () {
      final original = {
        'Tantallon': 'C:/images/castle.png',
        'Elf Village': 'C:/images/elven.png',
      };

      final md = MarkdownConfigParser.serializeAreaTable(
        original,
        'Area Images',
        'Area',
        'Image',
      );
      final parsed = MarkdownConfigParser.parseAreaTable(md);

      expect(parsed, original);
    });

    test('handles empty table', () {
      const md = '''
# Area Images

| Area | Image |
|---|---|
''';
      final map = MarkdownConfigParser.parseAreaTable(md);
      expect(map, isEmpty);
    });
  });

  group('MarkdownConfigParser — area audio', () {
    test('parses area tracks and battle themes', () {
      const md = '''
# Area Audio

## Area Tracks

| Area | Track |
|---|---|
| Tantallon | C:/music/town.mp3 |
| Forest | C:/music/forest.mp3 |

## Battle Themes

1. C:/music/battle1.mp3
2. C:/music/battle2.mp3
3. C:/music/battle3.mp3
''';
      final result = MarkdownConfigParser.parseAreaAudio(md);
      expect(result.tracks, hasLength(2));
      expect(result.tracks['Tantallon'], 'C:/music/town.mp3');
      expect(result.tracks['Forest'], 'C:/music/forest.mp3');
      expect(result.battleThemes, hasLength(3));
      expect(result.battleThemes[0], 'C:/music/battle1.mp3');
      expect(result.battleThemes[2], 'C:/music/battle3.mp3');
    });

    test('round-trips area audio through serialize/parse', () {
      final tracks = {
        'Tantallon': 'C:/music/town.mp3',
        'Inn': 'C:/music/tavern.mp3',
      };
      final themes = ['C:/music/battle1.mp3', 'C:/music/battle2.mp3'];

      final md = MarkdownConfigParser.serializeAreaAudio(tracks, themes);
      final parsed = MarkdownConfigParser.parseAreaAudio(md);

      expect(parsed.tracks, tracks);
      expect(parsed.battleThemes, themes);
    });

    test('handles audio with no battle themes', () {
      const md = '''
# Area Audio

## Area Tracks

| Area | Track |
|---|---|
| Town | C:/music/town.mp3 |
''';
      final result = MarkdownConfigParser.parseAreaAudio(md);
      expect(result.tracks, hasLength(1));
      expect(result.battleThemes, isEmpty);
    });
  });

  group('MarkdownConfigParser — unified area config', () {
    test('parses area with all subsections', () {
      const md = '''
# Tantallon
Coordinates:
- 0,0
- 1,0

Backgrounds:
- C:/images/castle.png
- C:/images/castle2.png

Music:
- C:/music/town.mp3
''';
      final config = MarkdownConfigParser.parseUnifiedAreaConfig(md);
      expect(config.areas, hasLength(1));
      final area = config.areas['Tantallon']!;
      expect(area.name, 'Tantallon');
      expect(area.coordinates, ['0,0', '1,0']);
      expect(area.backgrounds, ['C:/images/castle.png', 'C:/images/castle2.png']);
      expect(area.music, ['C:/music/town.mp3']);
    });

    test('parses multiple areas', () {
      const md = '''
# Tantallon
Coordinates:
- 0,0

Music:
- C:/music/town.mp3

# Inns
Coordinates:
- -10,10
- 100,36

Music:
- C:/music/inn.mp3
''';
      final config = MarkdownConfigParser.parseUnifiedAreaConfig(md);
      expect(config.areas, hasLength(2));
      expect(config.areas['Tantallon']!.coordinates, ['0,0']);
      expect(config.areas['Inns']!.coordinates, ['-10,10', '100,36']);
      expect(config.areas['Inns']!.music, ['C:/music/inn.mp3']);
    });

    test('parses area without coordinates', () {
      const md = '''
# Inns
Music:
- C:/music/inn.mp3

Backgrounds:
- C:/images/inn.png
''';
      final config = MarkdownConfigParser.parseUnifiedAreaConfig(md);
      final area = config.areas['Inns']!;
      expect(area.coordinates, isEmpty);
      expect(area.music, ['C:/music/inn.mp3']);
      expect(area.backgrounds, ['C:/images/inn.png']);
    });

    test('parses battle themes section', () {
      const md = '''
# Tantallon
Coordinates:
- 0,0

# Battle Themes
- C:/music/battle1.mp3
- C:/music/battle2.mp3
- C:/music/battle3.mp3
''';
      final config = MarkdownConfigParser.parseUnifiedAreaConfig(md);
      expect(config.areas, hasLength(1));
      expect(config.battleThemes, hasLength(3));
      expect(config.battleThemes[0], 'C:/music/battle1.mp3');
      expect(config.battleThemes[2], 'C:/music/battle3.mp3');
    });

    test('parses empty content', () {
      final config = MarkdownConfigParser.parseUnifiedAreaConfig('');
      expect(config.areas, isEmpty);
      expect(config.battleThemes, isEmpty);
    });

    test('lookupByCoord finds area by coordinates', () {
      const md = '''
# Tantallon
Coordinates:
- 0,0
- 1,0

# Forest
Coordinates:
- 5,10
''';
      final config = MarkdownConfigParser.parseUnifiedAreaConfig(md);
      expect(config.lookupByCoord(0, 0)?.name, 'Tantallon');
      expect(config.lookupByCoord(1, 0)?.name, 'Tantallon');
      expect(config.lookupByCoord(5, 10)?.name, 'Forest');
      expect(config.lookupByCoord(99, 99), isNull);
    });

    test('round-trips through serialize/parse', () {
      const md = '''
# Tantallon
Coordinates:
- 0,0

Backgrounds:
- C:/images/castle.png

Music:
- C:/music/town.mp3

# Inns
Backgrounds:
- C:/images/inn.png

Music:
- C:/music/inn.mp3
- C:/music/inn_alt.mp3

# Battle Themes
- C:/music/battle1.mp3
- C:/music/battle2.mp3
''';
      final original = MarkdownConfigParser.parseUnifiedAreaConfig(md);
      final serialized =
          MarkdownConfigParser.serializeUnifiedAreaConfig(original);
      final reparsed =
          MarkdownConfigParser.parseUnifiedAreaConfig(serialized);

      expect(reparsed.areas.length, original.areas.length);
      for (final name in original.areas.keys) {
        final o = original.areas[name]!;
        final r = reparsed.areas[name]!;
        expect(r.name, o.name);
        expect(r.coordinates, o.coordinates);
        expect(r.backgrounds, o.backgrounds);
        expect(r.music, o.music);
      }
      expect(reparsed.battleThemes, original.battleThemes);
    });

    test('handles Windows paths with backslashes', () {
      const md = r'''
# Tantallon
Music:
- C:\Users\samil\Music\town.mp3

Backgrounds:
- C:\Users\samil\Images\castle.png
''';
      final config = MarkdownConfigParser.parseUnifiedAreaConfig(md);
      final area = config.areas['Tantallon']!;
      expect(area.music, [r'C:\Users\samil\Music\town.mp3']);
      expect(area.backgrounds, [r'C:\Users\samil\Images\castle.png']);
    });
  });

  group('MarkdownConfigParser — color parsing', () {
    test('round-trips opaque colors as 6-digit hex', () {
      final rules = [
        TriggerRule(
          id: 'hl_01',
          name: 'Color Test',
          pattern: 'x',
          action: TriggerAction.highlight,
          highlightForeground: const Color(0xFF00FF00),
        ),
      ];
      final md = MarkdownConfigParser.serializeImmersions(rules);
      expect(md, contains('#00FF00'));

      final parsed = MarkdownConfigParser.parseImmersions(md);
      expect(parsed[0].highlightForeground, const Color(0xFF00FF00));
    });

    test('round-trips translucent colors as 8-digit hex', () {
      final rules = [
        TriggerRule(
          id: 'hl_01',
          name: 'Alpha Test',
          pattern: 'x',
          action: TriggerAction.highlight,
          highlightForeground: const Color(0x8000FF00),
        ),
      ];
      final md = MarkdownConfigParser.serializeImmersions(rules);
      expect(md, contains('#8000FF00'));

      final parsed = MarkdownConfigParser.parseImmersions(md);
      expect(parsed[0].highlightForeground, const Color(0x8000FF00));
    });
  });
}
