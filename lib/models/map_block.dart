import 'map_tile_kind.dart';

/// A rectangular block of ASCII map tiles captured between a pair of
/// `+---...---+` borders. Rendered by the terminal view as a grid widget
/// with uniform cells and a styled frame (instead of per-line ASCII).
class MapBlock {
  final List<List<MapTile>> rows;

  const MapBlock(this.rows);

  int get rowCount => rows.length;
  int get colCount => rows.isEmpty ? 0 : rows.first.length;
}

/// One cell inside a [MapBlock]. Either a 2-char terrain glyph (looked up
/// through the emoji table at render time) or the player position.
sealed class MapTile {
  const MapTile();
}

/// A base terrain tile carrying the raw 2-char ASCII so the renderer can
/// map it to an emoji (or fall back to the raw glyphs for unknown tiles).
class TerrainTile extends MapTile {
  final String ascii;
  const TerrainTile(this.ascii);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TerrainTile && other.ascii == ascii);

  @override
  int get hashCode => ascii.hashCode;
}

/// The player's position marker — rendered as a pulsing 🔴.
class PlayerTile extends MapTile {
  const PlayerTile();

  @override
  bool operator ==(Object other) => other is PlayerTile;

  @override
  int get hashCode => 0;
}

/// Parses one `| tile tile tile … |` content row into [MapTile]s. Returns
/// an empty list if the line isn't a map content row.
///
/// Tile grammar: cells are 2 ASCII chars separated by single spaces. The
/// 4-char `<[]>` player marker is the one exception; it replaces what would
/// otherwise be two cells.
List<MapTile> parseMapRow(String plainText) {
  var content = plainText.trimRight();
  if (!content.startsWith('|') || !content.endsWith('|')) return const [];
  content = content.substring(1, content.length - 1);

  final tiles = <MapTile>[];
  var i = 0;
  while (i < content.length) {
    final ch = content[i];
    if (ch == ' ') {
      i++;
      continue;
    }
    if (i + 4 <= content.length && content.substring(i, i + 4) == '<[]>') {
      tiles.add(const PlayerTile());
      i += 4;
      continue;
    }
    if (i + 2 <= content.length) {
      // A well-formed map tile is always two non-space chars. If the next
      // char is a space, we're chunking across a word boundary in prose —
      // this row isn't a map row at all. (`content[i]` is guaranteed
      // non-space by the skip loop above.)
      if (content[i + 1] == ' ') return const [];
      tiles.add(TerrainTile(content.substring(i, i + 2)));
      i += 2;
    } else {
      // Odd trailing char — skip.
      i++;
    }
  }
  return tiles;
}

/// Heuristic: does this collection of parsed rows actually describe a map?
///
/// The row-level parser accepts unknown 2-char tokens so the renderer can
/// show uncommon tiles (e.g. area-specific landmarks) as raw glyphs. But a
/// block of *entirely* unknown tokens is almost certainly prose that was
/// chunked into tiles by accident — a shop listing, an info card, etc.
/// Require at least one tile to classify to a known [TileKind].
bool looksLikeMapBlock(List<List<MapTile>> rows) {
  if (rows.isEmpty) return false;
  for (final row in rows) {
    for (final tile in row) {
      if (tile is TerrainTile &&
          classifyTile(tile.ascii) != TileKind.unknown) {
        return true;
      }
    }
  }
  return false;
}
