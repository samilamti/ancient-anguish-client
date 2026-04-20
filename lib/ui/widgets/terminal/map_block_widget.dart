import 'package:flutter/material.dart';

import '../../../models/map_block.dart';
import '../../../models/map_tile_kind.dart';
import 'map_cell_painter.dart';

/// Renders a captured [MapBlock] as a bordered grid of painted tiles.
///
/// Each cell is a fixed square sized off the terminal font size, so the
/// grid scales with the user's text-size setting. Tiles are drawn via
/// [MapTilePainter], which picks up neighbour info for autotiling of
/// roads and water.
class MapBlockWidget extends StatelessWidget {
  final MapBlock block;
  final double fontSize;

  const MapBlockWidget({
    super.key,
    required this.block,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = MapPalette.fromTheme(theme);
    // Themed painted tiles look better with a bit more room than the
    // old emoji cells, so bump the cell size slightly.
    final cell = (fontSize * 2.0).roundToDouble();

    // Pre-classify every tile so the painter lookups are O(1).
    final kinds = <List<TileKind>>[
      for (final row in block.rows)
        [
          for (final tile in row)
            switch (tile) {
              PlayerTile() => TileKind.grass, // underlying terrain
              TerrainTile(:final ascii) => classifyTile(ascii),
            },
        ],
    ];

    TileKind kindAt(int r, int c) {
      if (r < 0 || r >= kinds.length) return TileKind.unknown;
      final row = kinds[r];
      if (c < 0 || c >= row.length) return TileKind.unknown;
      return row[c];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withAlpha(180),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: palette.frame.withAlpha(120),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.frame.withAlpha(40),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var r = 0; r < block.rows.length; r++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var c = 0; c < block.rows[r].length; c++)
                      _MapCell(
                        tile: block.rows[r][c],
                        kind: kinds[r][c],
                        north: kindAt(r - 1, c),
                        south: kindAt(r + 1, c),
                        east: kindAt(r, c + 1),
                        west: kindAt(r, c - 1),
                        palette: palette,
                        size: cell,
                        fontSize: fontSize,
                        positionSeed: r * 1000 + c,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapCell extends StatelessWidget {
  final MapTile tile;
  final TileKind kind;
  final TileKind north;
  final TileKind south;
  final TileKind east;
  final TileKind west;
  final MapPalette palette;
  final double size;
  final double fontSize;
  final int positionSeed;

  const _MapCell({
    required this.tile,
    required this.kind,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.palette,
    required this.size,
    required this.fontSize,
    required this.positionSeed,
  });

  @override
  Widget build(BuildContext context) {
    final String? rawAscii = switch (tile) {
      PlayerTile() => null,
      TerrainTile(:final ascii) => ascii,
    };
    final tooltip = switch (tile) {
      PlayerTile() => 'You',
      TerrainTile(:final ascii) => kind == TileKind.unknown
          ? 'Unknown tile ($ascii)'
          : tileName(kind),
    };

    final painter = CustomPaint(
      size: Size.square(size),
      painter: MapTilePainter(
        kind: kind,
        rawAscii: rawAscii,
        north: north,
        south: south,
        east: east,
        west: west,
        palette: palette,
        positionSeed: positionSeed,
      ),
    );

    final Widget cell = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          painter,
          if (tile is PlayerTile)
            _PulsingPlayerMarker(size: size, color: palette.player),
        ],
      ),
    );

    return Tooltip(message: tooltip, child: cell);
  }
}

/// A themed pulsing dot for the player's current tile. Painted rather than
/// rendered as an emoji so it sits naturally on top of any terrain
/// background and picks up the active theme's primary colour.
class _PulsingPlayerMarker extends StatefulWidget {
  final double size;
  final Color color;

  const _PulsingPlayerMarker({required this.size, required this.color});

  @override
  State<_PulsingPlayerMarker> createState() => _PulsingPlayerMarkerState();
}

class _PulsingPlayerMarkerState extends State<_PulsingPlayerMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _PlayerDotPainter(color: widget.color, t: t),
          );
        },
      ),
    );
  }
}

class _PlayerDotPainter extends CustomPainter {
  final Color color;
  final double t; // 0..1 animation phase

  _PlayerDotPainter({required this.color, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final dotRadius = size.width * 0.18;
    // Outer pulsing halo.
    final haloR = dotRadius + size.width * (0.12 + 0.08 * t);
    canvas.drawCircle(
      centre,
      haloR,
      Paint()..color = color.withAlpha((50 + 60 * t).round()),
    );
    // Inner ring.
    canvas.drawCircle(
      centre,
      dotRadius + size.width * 0.04,
      Paint()..color = color.withAlpha(220),
    );
    // Core.
    canvas.drawCircle(centre, dotRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PlayerDotPainter old) =>
      old.t != t || old.color != color;
}
