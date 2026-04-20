import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/map_tile_kind.dart';

void main() {
  group('classifyTile', () {
    test('base terrain tokens', () {
      expect(classifyTile('/\\'), TileKind.mountain);
      expect(classifyTile('^^'), TileKind.hills);
      expect(classifyTile('oo'), TileKind.grass);
      expect(classifyTile('OO'), TileKind.forest);
      expect(classifyTile('""'), TileKind.brush);
      expect(classifyTile('~~'), TileKind.water);
      expect(classifyTile('=='), TileKind.road);
      expect(classifyTile('::'), TileKind.cobble);
      expect(classifyTile('##'), TileKind.wall);
      expect(classifyTile('[]'), TileKind.building);
      expect(classifyTile('88'), TileKind.ruin);
    });

    test('road overlays collapse to road', () {
      expect(classifyTile('+o'), TileKind.road);
      expect(classifyTile('+O'), TileKind.road);
      expect(classifyTile('+^'), TileKind.road);
      expect(classifyTile('+"'), TileKind.road);
      expect(classifyTile('+@'), TileKind.road);
    });

    test('+| is a bridge', () {
      expect(classifyTile('+|'), TileKind.bridge);
    });

    test('landmarks', () {
      expect(classifyTile('@^'), TileKind.landmark);
      expect(classifyTile('@\\'), TileKind.landmark);
    });

    test('vegetation / edge composites', () {
      expect(classifyTile('Y\\'), TileKind.forest);
      expect(classifyTile('Y#'), TileKind.forest);
      expect(classifyTile('O#'), TileKind.forest);
      expect(classifyTile(':#'), TileKind.wall);
      expect(classifyTile('o#'), TileKind.wall);
    });

    test('unknown tokens fall through', () {
      expect(classifyTile('xy'), TileKind.unknown);
      expect(classifyTile(''), TileKind.unknown);
      expect(classifyTile('??'), TileKind.unknown);
    });
  });

  group('isRoadLike', () {
    test('matches road, bridge, and cobble', () {
      expect(isRoadLike(TileKind.road), isTrue);
      expect(isRoadLike(TileKind.bridge), isTrue);
      expect(isRoadLike(TileKind.cobble), isTrue);
    });

    test('rejects everything else', () {
      for (final kind in TileKind.values) {
        if (kind == TileKind.road ||
            kind == TileKind.bridge ||
            kind == TileKind.cobble) {
          continue;
        }
        expect(isRoadLike(kind), isFalse,
            reason: '$kind should not be roadlike');
      }
    });
  });

  group('tileName', () {
    test('covers every TileKind', () {
      for (final kind in TileKind.values) {
        final name = tileName(kind);
        expect(name, isNotEmpty);
        expect(name[0], matches(RegExp(r'[A-Z]')));
      }
    });
  });
}
