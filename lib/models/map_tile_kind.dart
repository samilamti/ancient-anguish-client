/// Semantic classification of a map tile for rendering purposes.
///
/// The MUD encodes each tile as 2 ASCII chars; several encodings collapse
/// into one visual family (all the `+X` road overlays are `road`,
/// everything that ends in `#` near a wall is `wall`, etc.). The painter
/// switches off this enum, so the number of draw routines stays small.
enum TileKind {
  mountain,
  hills,
  grass,
  forest,
  brush,
  water,
  road,
  bridge,
  cobble,
  wall,
  building,
  ruin,
  landmark,
  unknown,
}

/// Maps a raw 2-char tile to its [TileKind]. Unknown tokens fall through
/// to [TileKind.unknown] — the renderer shows them as the raw glyphs so
/// players can still read uncommon tiles.
TileKind classifyTile(String ascii) {
  switch (ascii) {
    // Base terrain.
    case '/\\':
      return TileKind.mountain;
    case '^^':
      return TileKind.hills;
    case 'oo':
      return TileKind.grass;
    case 'OO':
      return TileKind.forest;
    case '""':
      return TileKind.brush;
    case '~~':
      return TileKind.water;
    case '==':
      return TileKind.road;
    case '::':
      return TileKind.cobble;
    case '##':
      return TileKind.wall;
    case '[]':
      return TileKind.building;
    case '88':
      return TileKind.ruin;

    // Road overlays collapse into the road family so autotiling treats
    // them as a continuous ribbon across the map.
    case '+o':
    case '+O':
    case '+^':
    case '+"':
    case '+@':
      return TileKind.road;
    case '+|':
      return TileKind.bridge;

    // Landmark composites.
    case '@^':
    case '@\\':
      return TileKind.landmark;

    // Vegetation / edge composites — best-effort bucketing.
    case 'Y\\':
    case 'Y#':
    case 'O#':
      return TileKind.forest;
    case ':#':
    case 'o#':
      return TileKind.wall;
  }
  return TileKind.unknown;
}

/// Returns the short label that appears in a tile's tooltip.
String tileName(TileKind kind) {
  return switch (kind) {
    TileKind.mountain => 'Mountain',
    TileKind.hills => 'Hills',
    TileKind.grass => 'Grass',
    TileKind.forest => 'Forest',
    TileKind.brush => 'Brush',
    TileKind.water => 'Water',
    TileKind.road => 'Road',
    TileKind.bridge => 'Bridge',
    TileKind.cobble => 'Cobble',
    TileKind.wall => 'Wall',
    TileKind.building => 'Building',
    TileKind.ruin => 'Ruin',
    TileKind.landmark => 'Landmark',
    TileKind.unknown => 'Unknown',
  };
}

/// Tiles that the autotiler treats as "roadlike" when looking at
/// neighbours. Keeping bridges + cobble paths in this set means a paved
/// road flows smoothly onto a bridge or cobble stretch without visual
/// seams.
bool isRoadLike(TileKind kind) =>
    kind == TileKind.road ||
    kind == TileKind.bridge ||
    kind == TileKind.cobble;
