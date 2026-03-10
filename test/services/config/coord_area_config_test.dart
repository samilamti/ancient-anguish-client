import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/config/coord_area_config.dart';

void main() {
  late Directory tempDir;
  late String tempFilePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('coord_area_config_test_');
    tempFilePath = '${tempDir.path}/test_config.txt';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Helper to write config content and load it synchronously.
  CoordAreaConfig loadConfig(String content) {
    File(tempFilePath).writeAsStringSync(content);
    final config = CoordAreaConfig();
    config.loadFromFileSync(tempFilePath);
    return config;
  }

  group('CoordAreaConfig - parsing', () {
    test('parses basic coordinate and area name', () {
      final config = loadConfig('0,0\tTown Square');
      final entry = config.lookup(0, 0);
      expect(entry, isNotNull);
      expect(entry!.areaName, 'Town Square');
      expect(entry.audioPath, isNull);
    });

    test('parses entry with quoted audio path', () {
      final config = loadConfig('5,10\tForest\t"audio/forest.mp3"');
      final entry = config.lookup(5, 10);
      expect(entry, isNotNull);
      expect(entry!.areaName, 'Forest');
      expect(entry.audioPath, 'audio/forest.mp3');
    });

    test('parses entry with unquoted audio path', () {
      final config = loadConfig('5,10\tForest\taudio/forest.mp3');
      final entry = config.lookup(5, 10);
      expect(entry!.audioPath, 'audio/forest.mp3');
    });

    test('empty audio column produces null audioPath', () {
      final config = loadConfig('5,10\tForest\t');
      final entry = config.lookup(5, 10);
      expect(entry!.audioPath, isNull);
    });

    test('parses negative coordinates', () {
      final config = loadConfig('-3,-7\tDungeon');
      final entry = config.lookup(-3, -7);
      expect(entry, isNotNull);
      expect(entry!.areaName, 'Dungeon');
    });

    test('handles Windows-style paths in audio column', () {
      final config =
          loadConfig(r'1,2	Castle	"C:\music\castle.mp3"');
      final entry = config.lookup(1, 2);
      expect(entry!.audioPath, r'C:\music\castle.mp3');
    });
  });

  group('CoordAreaConfig - filtering', () {
    test('ignores comment lines starting with #', () {
      final config = loadConfig('# This is a comment\n0,0\tTown');
      expect(config.entries, hasLength(1));
      expect(config.lookup(0, 0)!.areaName, 'Town');
    });

    test('ignores indented comment lines', () {
      final config = loadConfig('  # Indented comment\n0,0\tTown');
      expect(config.entries, hasLength(1));
    });

    test('ignores blank lines', () {
      final config = loadConfig('0,0\tTown\n\n1,1\tForest');
      expect(config.entries, hasLength(2));
    });

    test('skips lines with fewer than 2 tab columns', () {
      final config = loadConfig('no tabs here\n0,0\tTown');
      expect(config.entries, hasLength(1));
    });

    test('skips lines with invalid coordinate format', () {
      final config = loadConfig('abc\tInvalid\n0,0\tTown');
      expect(config.entries, hasLength(1));
    });

    test('skips lines with empty area name', () {
      final config = loadConfig('0,0\t\n1,1\tForest');
      expect(config.entries, hasLength(1));
      expect(config.lookup(1, 1)!.areaName, 'Forest');
    });
  });

  group('CoordAreaConfig - lookup', () {
    test('returns entry for exact coordinate match', () {
      final config = loadConfig('3,7\tMarket');
      expect(config.lookup(3, 7), isNotNull);
    });

    test('returns null for unmapped coordinates', () {
      final config = loadConfig('3,7\tMarket');
      expect(config.lookup(0, 0), isNull);
    });

    test('later entries overwrite earlier for same coordinates', () {
      final config = loadConfig('0,0\tFirst\n0,0\tSecond');
      expect(config.lookup(0, 0)!.areaName, 'Second');
    });
  });

  group('CoordAreaConfig - reset', () {
    test('clears all entries', () {
      final config = loadConfig('0,0\tTown\n1,1\tForest');
      expect(config.entries, hasLength(2));
      config.reset();
      expect(config.entries, isEmpty);
      expect(config.lookup(0, 0), isNull);
    });
  });

  group('CoordAreaConfig - async loading', () {
    test('loadFromFile works same as loadFromFileSync', () async {
      File(tempFilePath).writeAsStringSync('5,5\tTemple\t"music.mp3"');
      final config = CoordAreaConfig();
      await config.loadFromFile(tempFilePath);
      final entry = config.lookup(5, 5);
      expect(entry, isNotNull);
      expect(entry!.areaName, 'Temple');
      expect(entry.audioPath, 'music.mp3');
    });

    test('loadFromFile handles nonexistent file gracefully', () async {
      final config = CoordAreaConfig();
      await config.loadFromFile('${tempDir.path}/nonexistent.txt');
      expect(config.entries, isEmpty);
    });
  });

  group('CoordAreaConfig - multi-entry file', () {
    test('loads multiple entries correctly', () {
      final config = loadConfig(
        '# Area configuration\n'
        '0,0\tTown Square\t"music/town.mp3"\n'
        '1,0\tNorth Road\n'
        '-1,0\tSouth Road\n'
        '0,1\tEast Path\t"music/path.mp3"\n',
      );
      expect(config.entries, hasLength(4));
      expect(config.lookup(0, 0)!.areaName, 'Town Square');
      expect(config.lookup(0, 0)!.audioPath, 'music/town.mp3');
      expect(config.lookup(1, 0)!.areaName, 'North Road');
      expect(config.lookup(1, 0)!.audioPath, isNull);
      expect(config.lookup(-1, 0)!.areaName, 'South Road');
      expect(config.lookup(0, 1)!.audioPath, 'music/path.mp3');
    });
  });
}
