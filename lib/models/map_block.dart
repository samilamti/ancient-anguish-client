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
      tiles.add(TerrainTile(content.substring(i, i + 2)));
      i += 2;
    } else {
      // Odd trailing char — skip.
      i++;
    }
  }
  return tiles;
}
