import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../models/map_tile_kind.dart';

/// Colours used by [MapTilePainter]. Derived from the active `ColorScheme`
/// so the painted map shifts with the user's selected theme. Hues are
/// gently biased toward natural tones (forest → green, water → blue) while
/// letting the accent ride the app's primary.
class MapPalette {
  final Color frame;
  final Color grass;
  final Color hills;
  final Color mountain;
  final Color forest;
  final Color brush;
  final Color water;
  final Color waterDeep;
  final Color road;
  final Color roadEdge;
  final Color wall;
  final Color building;
  final Color ruin;
  final Color landmark;
  final Color player;
  final Color unknown;
  final Color onUnknown;

  const MapPalette({
    required this.frame,
    required this.grass,
    required this.hills,
    required this.mountain,
    required this.forest,
    required this.brush,
    required this.water,
    required this.waterDeep,
    required this.road,
    required this.roadEdge,
    required this.wall,
    required this.building,
    required this.ruin,
    required this.landmark,
    required this.player,
    required this.unknown,
    required this.onUnknown,
  });

  /// Build a palette tuned for [theme]. We reach for recognisable terrain
  /// hues first and only lean on ColorScheme for frame / player / landmark
  /// — that keeps maps legible without dragging in whatever the user's
  /// custom scheme is doing.
  factory MapPalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    return MapPalette(
      frame: scheme.primary,
      grass: const Color(0xFF3A5E34),
      hills: const Color(0xFF6D7A4A),
      mountain: const Color(0xFF6E6458),
      forest: const Color(0xFF264A2B),
      brush: const Color(0xFF8F8A3F),
      water: const Color(0xFF2D6EA4),
      waterDeep: const Color(0xFF1D4E7C),
      road: const Color(0xFFB39865),
      roadEdge: const Color(0xFF6B5A3A),
      wall: const Color(0xFF4A403A),
      building: scheme.primary,
      ruin: const Color(0xFF5C4436),
      landmark: scheme.secondary,
      player: scheme.primary,
      unknown: scheme.surface.withAlpha(120),
      onUnknown: scheme.onSurface,
    );
  }
}

/// Paints a single map cell.
///
/// Autotiling: for [TileKind.road] / [TileKind.cobble] / [TileKind.bridge]
/// and [TileKind.water] we look at the cardinal neighbours so the painter
/// can draw flowing ribbons and smooth coastlines instead of chunky
/// isolated squares.
class MapTilePainter extends CustomPainter {
  final TileKind kind;
  final String? rawAscii; // for fallback rendering on unknown tiles
  final TileKind north;
  final TileKind south;
  final TileKind east;
  final TileKind west;
  final MapPalette palette;
  final int positionSeed; // deterministic variation per cell

  const MapTilePainter({
    required this.kind,
    required this.rawAscii,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.palette,
    required this.positionSeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintBase(canvas, size);
    switch (kind) {
      case TileKind.mountain:
        _paintMountain(canvas, size);
        break;
      case TileKind.hills:
        _paintHills(canvas, size);
        break;
      case TileKind.grass:
        _paintGrassTufts(canvas, size);
        break;
      case TileKind.forest:
        _paintForest(canvas, size);
        break;
      case TileKind.brush:
        _paintBrush(canvas, size);
        break;
      case TileKind.water:
        _paintWater(canvas, size);
        break;
      case TileKind.road:
      case TileKind.cobble:
      case TileKind.bridge:
        _paintRoad(canvas, size);
        break;
      case TileKind.wall:
        _paintWall(canvas, size);
        break;
      case TileKind.building:
        _paintBuilding(canvas, size);
        break;
      case TileKind.ruin:
        _paintRuin(canvas, size);
        break;
      case TileKind.landmark:
        _paintLandmark(canvas, size);
        break;
      case TileKind.unknown:
        _paintUnknown(canvas, size);
        break;
    }
  }

  // ── Base layer ──
  //
  // Non-water / non-road tiles get a grass-tinted base so isolated glyphs
  // read against the surrounding terrain. Water and road are painted
  // end-to-end by their own routines.

  void _paintBase(Canvas canvas, Size size) {
    final baseColor = switch (kind) {
      TileKind.water => palette.water,
      TileKind.road => palette.grass,
      TileKind.cobble => palette.grass,
      TileKind.bridge => palette.water,
      TileKind.mountain => palette.mountain.withAlpha(90),
      TileKind.hills => palette.hills.withAlpha(120),
      TileKind.forest => palette.grass,
      TileKind.brush => palette.hills.withAlpha(140),
      TileKind.wall => palette.wall,
      TileKind.building => palette.grass,
      TileKind.ruin => palette.grass,
      TileKind.landmark => palette.grass,
      TileKind.grass => palette.grass,
      TileKind.unknown => palette.unknown,
    };
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = baseColor);
  }

  // ── Terrain routines ──

  void _paintMountain(Canvas canvas, Size size) {
    final paint = Paint()..color = palette.mountain;
    final shadow = Paint()..color = palette.mountain.withAlpha(200);
    final w = size.width;
    final h = size.height;
    // Main peak + side peak. Shadow triangle gives crude depth.
    final peak = Path()
      ..moveTo(w * 0.15, h * 0.85)
      ..lineTo(w * 0.5, h * 0.15)
      ..lineTo(w * 0.85, h * 0.85)
      ..close();
    canvas.drawPath(peak, paint);
    // Snow cap.
    final cap = Path()
      ..moveTo(w * 0.38, h * 0.35)
      ..lineTo(w * 0.5, h * 0.15)
      ..lineTo(w * 0.62, h * 0.35)
      ..close();
    canvas.drawPath(cap, Paint()..color = Colors.white.withAlpha(210));
    // Shadow side.
    final shade = Path()
      ..moveTo(w * 0.5, h * 0.15)
      ..lineTo(w * 0.85, h * 0.85)
      ..lineTo(w * 0.55, h * 0.85)
      ..close();
    canvas.drawPath(shade, shadow);
  }

  void _paintHills(Canvas canvas, Size size) {
    final paint = Paint()..color = palette.hills;
    final h = size.height;
    final w = size.width;
    final leftHill = Path()
      ..addArc(
        Rect.fromLTWH(-w * 0.1, h * 0.35, w * 0.7, h * 0.9),
        math.pi,
        math.pi,
      );
    final rightHill = Path()
      ..addArc(
        Rect.fromLTWH(w * 0.35, h * 0.45, w * 0.7, h * 0.8),
        math.pi,
        math.pi,
      );
    canvas.drawPath(leftHill, paint);
    canvas.drawPath(rightHill, paint..color = palette.hills.withAlpha(220));
  }

  void _paintGrassTufts(Canvas canvas, Size size) {
    // Three tiny tufts at deterministic positions so rebuilds don't flicker.
    final paint = Paint()
      ..color = palette.grass.withAlpha(200)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.5, size.width * 0.06);
    final rnd = math.Random(positionSeed);
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.2 + rnd.nextDouble() * 0.6);
      final baseY = size.height * (0.55 + rnd.nextDouble() * 0.35);
      final height = size.height * (0.15 + rnd.nextDouble() * 0.15);
      canvas.drawLine(
        Offset(x, baseY),
        Offset(x, baseY - height),
        paint..color = palette.grass.withAlpha(210),
      );
    }
  }

  void _paintForest(Canvas canvas, Size size) {
    // Two overlapping tree canopies — offsets vary per seed so a row of
    // forest doesn't look stamped.
    final rnd = math.Random(positionSeed);
    final treePaint = Paint()..color = palette.forest;
    final highlight = Paint()..color = palette.forest.withAlpha(160);
    final trunkPaint = Paint()..color = palette.wall;

    void drawTree(Offset base, double radius) {
      canvas.drawRect(
        Rect.fromCenter(
          center: base.translate(0, radius * 0.45),
          width: radius * 0.25,
          height: radius * 0.5,
        ),
        trunkPaint,
      );
      canvas.drawCircle(base, radius, treePaint);
      canvas.drawCircle(
        base.translate(-radius * 0.25, -radius * 0.25),
        radius * 0.55,
        highlight,
      );
    }

    final w = size.width;
    final h = size.height;
    drawTree(
      Offset(w * (0.28 + rnd.nextDouble() * 0.08), h * 0.4),
      w * 0.28,
    );
    drawTree(
      Offset(w * (0.62 + rnd.nextDouble() * 0.08), h * 0.52),
      w * 0.24,
    );
  }

  void _paintBrush(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.brush
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width * 0.045)
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(positionSeed ^ 0x42);
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.15 + rnd.nextDouble() * 0.7);
      final y = size.height * (0.5 + rnd.nextDouble() * 0.35);
      final len = size.width * (0.15 + rnd.nextDouble() * 0.1);
      canvas.drawLine(Offset(x, y), Offset(x, y - len), paint);
      // Two side blades per stem for that "wheat" silhouette.
      canvas.drawLine(
        Offset(x, y - len * 0.6),
        Offset(x - len * 0.35, y - len * 0.9),
        paint,
      );
      canvas.drawLine(
        Offset(x, y - len * 0.6),
        Offset(x + len * 0.35, y - len * 0.9),
        paint,
      );
    }
  }

  void _paintWater(Canvas canvas, Size size) {
    // Already tinted blue by _paintBase. Darken the deep pockets and draw
    // shore strokes along sides that border non-water tiles.
    final ripple = Paint()
      ..color = palette.waterDeep
      ..strokeWidth = math.max(1, size.width * 0.05)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Two tiny ripples — placed away from any shore we might draw.
    final rnd = math.Random(positionSeed ^ 0xA5);
    for (var i = 0; i < 2; i++) {
      final cx = size.width * (0.3 + rnd.nextDouble() * 0.4);
      final cy = size.height * (0.3 + rnd.nextDouble() * 0.4);
      final r = size.width * 0.12;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        ripple,
      );
    }
    // Shores on non-water neighbours.
    final shore = Paint()
      ..color = palette.grass
      ..strokeWidth = math.max(1.5, size.width * 0.12)
      ..strokeCap = StrokeCap.square;
    if (north != TileKind.water && north != TileKind.bridge) {
      canvas.drawLine(
          const Offset(0, 0), Offset(size.width, 0), shore);
    }
    if (south != TileKind.water && south != TileKind.bridge) {
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), shore);
    }
    if (east != TileKind.water && east != TileKind.bridge) {
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), shore);
    }
    if (west != TileKind.water && west != TileKind.bridge) {
      canvas.drawLine(
          const Offset(0, 0), Offset(0, size.height), shore);
    }
  }

  void _paintRoad(Canvas canvas, Size size) {
    // Ribbon laid between cardinal neighbours that are also roads.
    final w = size.width;
    final h = size.height;
    final mid = Offset(w / 2, h / 2);
    final width = w * 0.55;
    final edgeWidth = width + math.max(2, w * 0.08);

    final edgePaint = Paint()
      ..color = palette.roadEdge
      ..strokeCap = StrokeCap.square
      ..strokeWidth = edgeWidth
      ..style = PaintingStyle.stroke;
    final facePaint = Paint()
      ..color = palette.road
      ..strokeCap = StrokeCap.square
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    final n = isRoadLike(north);
    final s = isRoadLike(south);
    final e = isRoadLike(east);
    final wLink = isRoadLike(west);

    void stroke(Offset a, Offset b) {
      canvas.drawLine(a, b, edgePaint);
      canvas.drawLine(a, b, facePaint);
    }

    // No connections → a square patch (looks like a waypoint).
    if (!n && !s && !e && !wLink) {
      final rect = Rect.fromCenter(center: mid, width: width, height: width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(math.max(2, w * 0.04)),
            Radius.circular(w * 0.15)),
        Paint()..color = palette.roadEdge,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(w * 0.12)),
        Paint()..color = palette.road,
      );
    } else {
      if (n) stroke(mid, Offset(mid.dx, 0));
      if (s) stroke(mid, Offset(mid.dx, h));
      if (e) stroke(mid, Offset(w, mid.dy));
      if (wLink) stroke(mid, Offset(0, mid.dy));

      // Centre cap so edge lines don't leave a seam at junctions.
      canvas.drawCircle(mid, width * 0.5, facePaint..style = PaintingStyle.fill);
    }

    // Bridge overlay — thin planks across the ribbon.
    if (kind == TileKind.bridge) {
      final plank = Paint()
        ..color = palette.roadEdge
        ..strokeWidth = math.max(1, w * 0.05);
      const count = 4;
      for (var i = 1; i <= count; i++) {
        final t = i / (count + 1);
        canvas.drawLine(
          Offset(mid.dx - width / 2, h * t),
          Offset(mid.dx + width / 2, h * t),
          plank,
        );
      }
    }

    // Cobble overlay — scattered dots on the road face.
    if (kind == TileKind.cobble) {
      final dot = Paint()..color = palette.roadEdge;
      final rnd = math.Random(positionSeed ^ 0xC0);
      for (var i = 0; i < 6; i++) {
        final dx = mid.dx + (rnd.nextDouble() - 0.5) * width * 0.8;
        final dy = mid.dy + (rnd.nextDouble() - 0.5) * width * 0.8;
        canvas.drawCircle(Offset(dx, dy), math.max(0.8, w * 0.035), dot);
      }
    }
  }

  void _paintWall(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.18,
      size.width * 0.84,
      size.height * 0.64,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.08)),
      Paint()..color = palette.wall,
    );
    // Rough blocks.
    final blockPaint = Paint()
      ..color = palette.wall.withAlpha(220)
      ..strokeWidth = math.max(1, size.width * 0.04)
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(rect.left, rect.top + rect.height / 2),
      Offset(rect.right, rect.top + rect.height / 2),
      blockPaint,
    );
    canvas.drawLine(
      Offset(rect.left + rect.width / 2, rect.top),
      Offset(rect.left + rect.width / 2, rect.top + rect.height / 2),
      blockPaint,
    );
    canvas.drawLine(
      Offset(rect.left + rect.width * 0.3, rect.top + rect.height / 2),
      Offset(rect.left + rect.width * 0.3, rect.bottom),
      blockPaint,
    );
    canvas.drawLine(
      Offset(rect.left + rect.width * 0.75, rect.top + rect.height / 2),
      Offset(rect.left + rect.width * 0.75, rect.bottom),
      blockPaint,
    );
  }

  void _paintBuilding(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.32,
      size.width * 0.64,
      size.height * 0.58,
    );
    canvas.drawRect(body, Paint()..color = palette.building);
    // Roof.
    final roof = Path()
      ..moveTo(size.width * 0.10, size.height * 0.38)
      ..lineTo(size.width * 0.50, size.height * 0.10)
      ..lineTo(size.width * 0.90, size.height * 0.38)
      ..close();
    canvas.drawPath(roof, Paint()..color = palette.roadEdge);
    // Door.
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.44,
        size.height * 0.60,
        size.width * 0.14,
        size.height * 0.30,
      ),
      Paint()..color = palette.wall,
    );
  }

  void _paintRuin(Canvas canvas, Size size) {
    final paint = Paint()..color = palette.ruin;
    // Three broken stubs.
    canvas.drawRect(
      Rect.fromLTWH(
          size.width * 0.18, size.height * 0.55, size.width * 0.18, size.height * 0.3),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
          size.width * 0.45, size.height * 0.40, size.width * 0.15, size.height * 0.45),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
          size.width * 0.66, size.height * 0.62, size.width * 0.16, size.height * 0.22),
      paint,
    );
  }

  void _paintLandmark(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * 0.62);
    final r = size.width * 0.22;
    // Glowing rim.
    canvas.drawCircle(
      centre,
      r * 1.4,
      Paint()..color = palette.landmark.withAlpha(70),
    );
    // Teardrop pin.
    final pin = Path()
      ..moveTo(centre.dx, size.height * 0.18)
      ..quadraticBezierTo(
        centre.dx + r,
        centre.dy - r * 0.2,
        centre.dx,
        centre.dy + r * 0.9,
      )
      ..quadraticBezierTo(
        centre.dx - r,
        centre.dy - r * 0.2,
        centre.dx,
        size.height * 0.18,
      )
      ..close();
    canvas.drawPath(pin, Paint()..color = palette.landmark);
    canvas.drawCircle(centre, r * 0.35, Paint()..color = palette.wall);
  }

  void _paintUnknown(Canvas canvas, Size size) {
    // Render the raw 2-char token so the player has something to match
    // against the MUD's help pages for uncommon tiles.
    if (rawAscii == null || rawAscii!.isEmpty) return;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: size.width * 0.42,
        fontWeight: FontWeight.bold,
        fontFamily: 'JetBrainsMono',
      ),
    )
      ..pushStyle(ui.TextStyle(color: palette.onUnknown))
      ..addText(rawAscii!);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: size.width));
    canvas.drawParagraph(
      paragraph,
      Offset(0, (size.height - paragraph.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant MapTilePainter old) {
    return old.kind != kind ||
        old.north != north ||
        old.south != south ||
        old.east != east ||
        old.west != west ||
        old.palette != palette ||
        old.positionSeed != positionSeed ||
        old.rawAscii != rawAscii;
  }
}
