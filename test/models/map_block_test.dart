import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/map_block.dart';
import 'package:ancient_anguish_client/models/map_tile_kind.dart';

void main() {
  group('parseMapRow', () {
    test('parses a simple terrain row', () {
      final tiles = parseMapRow('| /\\ oo OO ~~ == |');
      expect(tiles, hasLength(5));
      expect(tiles[0], isA<TerrainTile>());
      expect((tiles[0] as TerrainTile).ascii, '/\\');
      expect((tiles[1] as TerrainTile).ascii, 'oo');
      expect((tiles[4] as TerrainTile).ascii, '==');
    });

    test('parses the <[]> player marker as PlayerTile', () {
      final tiles = parseMapRow('| +|<[]>== |');
      expect(tiles, hasLength(3));
      expect(tiles[0], const TerrainTile('+|'));
      expect(tiles[1], const PlayerTile());
      expect(tiles[2], const TerrainTile('=='));
    });

    test('returns empty list for a non-map-content row', () {
      expect(parseMapRow('+--------+'), isEmpty);
      expect(parseMapRow('A room description.'), isEmpty);
      expect(parseMapRow(''), isEmpty);
    });

    test('tolerates trailing whitespace after closing pipe', () {
      final tiles = parseMapRow('| oo oo |   ');
      expect(tiles, hasLength(2));
    });

    test('handles contiguous tiles without surrounding spaces around marker',
        () {
      // Real Tantallon map sample: `... +|<[]>== ==` (no space either side
      // of the player marker).
      final tiles = parseMapRow('| +O +|<[]>== == |');
      expect(tiles, hasLength(5));
      expect(tiles[1], const TerrainTile('+|'));
      expect(tiles[2], const PlayerTile());
      expect(tiles[3], const TerrainTile('=='));
      expect(tiles[4], const TerrainTile('=='));
    });

    test('rejects prose rows whose 2-char chunks span word boundaries', () {
      // Shop-listing interiors: tokens like `"a "` / `"e "` give it away.
      expect(
        parseMapRow('|     a dart.....................94      |'),
        isEmpty,
      );
      expect(
        parseMapRow('|     a throwing knife..........536      |'),
        isEmpty,
      );
      expect(
        parseMapRow('|     a hunga-munga............1700      |'),
        isEmpty,
      );
    });

    test('rejects a short prose header row', () {
      // "We sell only the best throwing weapons" — the words alternate
      // even / odd length so several 2-char chunks include a trailing space.
      expect(
        parseMapRow('| We sell only the best throwing weapons |'),
        isEmpty,
      );
    });
  });

  group('MapBlock', () {
    test('exposes row + col counts', () {
      final block = MapBlock([
        [const TerrainTile('oo'), const TerrainTile('OO')],
        [const TerrainTile('~~'), const PlayerTile()],
      ]);
      expect(block.rowCount, 2);
      expect(block.colCount, 2);
    });

    test('empty block reports zero dimensions', () {
      const block = MapBlock([]);
      expect(block.rowCount, 0);
      expect(block.colCount, 0);
    });
  });

  group('looksLikeMapBlock', () {
    test('empty rows → false', () {
      expect(looksLikeMapBlock(const []), isFalse);
    });

    test('only unknown tiles → false', () {
      // `xy` and `zz` aren't in classifyTile's vocabulary.
      expect(
        looksLikeMapBlock([
          [const TerrainTile('xy'), const TerrainTile('zz')],
        ]),
        isFalse,
      );
    });

    test('at least one known tile → true', () {
      expect(
        looksLikeMapBlock([
          [const TerrainTile('xy'), const TerrainTile('oo')], // oo = grass
        ]),
        isTrue,
      );
    });

    test('player-only row is not enough (grass underlay not counted)', () {
      expect(
        looksLikeMapBlock([
          [const PlayerTile()],
        ]),
        isFalse,
      );
    });

    test('every known TileKind case qualifies', () {
      // Spot-check: at least one tile per known family triggers true.
      for (final ascii in const ['/\\', '~~', '==', '##', '[]', '+o']) {
        expect(classifyTile(ascii), isNot(TileKind.unknown));
        expect(
          looksLikeMapBlock([
            [TerrainTile(ascii)],
          ]),
          isTrue,
          reason: ascii,
        );
      }
    });
  });

  group('MapTile equality', () {
    test('TerrainTile equality is based on ascii', () {
      expect(const TerrainTile('oo'), const TerrainTile('oo'));
      expect(const TerrainTile('oo') == const TerrainTile('OO'), isFalse);
    });

    test('PlayerTile instances are equal', () {
      expect(const PlayerTile(), const PlayerTile());
    });
  });
}
