import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/known_location.dart';
import '../../../providers/compass_provider.dart';
import '../../../providers/game_state_provider.dart';

/// Diameter of the compass disc on desktop, where there is room for it.
const double kCompassSize = 432;

/// Markers are plotted between these radii **as a fraction of the diameter**:
/// touching distance at the center, [kCompassRangeStadia] at the outer edge.
///
/// Fractions rather than pixels because the rose also renders small enough to
/// fit a phone (see [CompassRose.size]); the two were fixed at 32/152 px for
/// the 432 px disc, which is exactly these ratios.
const double _kMarkerMinRadiusFraction = 32 / kCompassSize;
const double _kMarkerMaxRadiusFraction = 152 / kCompassSize;

/// Width of a marker's label box, and its icon, at [kCompassSize]. Both scale
/// with the disc so labels crowd no worse at a smaller size — the *font* does
/// not scale, because 12pt is already the floor for readability and shrinking
/// it is what makes a scaled-down compass useless.
const double _kMarkerWidth = 124;
const double _kMarkerIconSize = 40;

/// How far above its dot a marker's icon starts, so the icon sits roughly
/// centred on the point rather than hanging below it.
const double _kMarkerOverhang = 18;

/// Clear space kept between two label boxes, so de-collided labels read as
/// separate rather than merely not-quite-touching.
const double _kLabelGap = 4;

/// De-collision search: how far a marker may slide from its plotted point, and
/// in what increments. Sliding is preferably **radial** — along the marker's own
/// bearing — because bearing is the reading that matters on a compass: it keeps
/// "which way do I go" exact and only stretches the distance.
const double _kMaxRadialNudge = 56;
const double _kNudgeStep = 7;

/// Sliding **across** the ray is the fallback, for the case radial cannot fix:
/// two labels whose rays are near perpendicular, where moving along either ray
/// never separates them. It bends the reported bearing, so it is capped twice —
/// in pixels, and as a tangent, so that a marker close to the player (where a
/// few pixels are many degrees) is swung less than a distant one.
const double _kMaxTangentialNudge = 28;
const double _kMaxTangentialTan = 0.27; // ~15 degrees

/// At most this many nearby locations get an icon + name label; anything
/// farther is still drawn as a small dot on the rose.
const int kMaxLabeledMarkers = 6;

/// Blender-rendered icons that exist under assets/images/compass/. Kinds
/// not listed here fall back to an emoji glyph until their art lands.
const Set<LocationKind> _kRenderedIconKinds = {...LocationKind.values};

const Map<LocationKind, String> _kKindEmoji = {
  LocationKind.city: '🏰',
  LocationKind.village: '🛖',
  LocationKind.bridge: '🌉',
  LocationKind.cave: '🕳️',
  LocationKind.temple: '⛪',
  LocationKind.camp: '⛺',
  LocationKind.fortress: '🛡️',
  LocationKind.hall: '🏛️',
  LocationKind.farm: '🌾',
  LocationKind.ruin: '🏚️',
  LocationKind.dwelling: '🏠',
  LocationKind.coast: '⚓',
  LocationKind.nature: '🌳',
  LocationKind.landmark: '📍',
};

/// Navigation compass floating over the terminal on desktop.
///
/// Compares the player's live position (from the CLIENT prompt line) with
/// the named locations of the official map and shows everything within
/// [kCompassRangeStadia] stadia at its true bearing — north up, nearer
/// locations closer to the center. Hidden while coordinates are unknown
/// (indoors, not logged in, disconnected).
///
/// On mobile the same information arrives via [CompassStrip] instead: the disc
/// is wider than a phone screen, so there it is opened on demand.
class CompassOverlay extends ConsumerWidget {
  const CompassOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCoordinates =
        ref.watch(gameStateProvider.select((s) => s.hasCoordinates));
    if (!hasCoordinates) return const SizedBox.shrink();

    return const IgnorePointer(child: CompassRose());
  }
}

/// The rose itself: disc, markers and the nearest-location chip.
///
/// [size] is the disc diameter. It exists so the compass can also be shown on
/// a phone, where [kCompassSize] does not fit — the geometry scales, the label
/// font does not.
class CompassRose extends ConsumerWidget {
  final double size;

  /// How many locations get a marker. Worth lowering along with [size]: the
  /// labels crowd the disc, and six of them on a phone-sized rose overlap.
  final int maxLabeledMarkers;

  /// Whether the disc carries any text — both the marker names and the cardinal
  /// letters. Off on a phone, where at half diameter there is room for neither;
  /// the north tick is emphasised instead so the rose still reads north-up, and
  /// the nearest-location chip below the disc still names somewhere.
  final bool showText;

  /// Show only the nearest location in each of the eight compass directions,
  /// dots included. In town a dozen entries share a couple of bearings, and on
  /// a small disc "what is the closest thing that way" is the whole question.
  final bool nearestPerDirection;

  const CompassRose({
    super.key,
    this.size = kCompassSize,
    this.maxLabeledMarkers = kMaxLabeledMarkers,
    this.showText = true,
    this.nearestPerDirection = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(nearbyLocationsProvider);
    final nearby = nearestPerDirection ? _nearestPerDirection(all) : all;
    final scheme = Theme.of(context).colorScheme;
    final nearest = nearby.isEmpty ? null : nearby.first;
    final scale = size / kCompassSize;

    final labeled = nearby.take(maxLabeledMarkers).toList();
    final markers = showText
        ? _placeMarkers(
            entries: labeled,
            labelSizes: [
              for (final entry in labeled)
                _measureLabel(
                  entry.location.shortName,
                  DefaultTextStyle.of(context)
                      .style
                      .merge(_labelStyle(scheme.onSurface)),
                  _kMarkerWidth * scale,
                  MediaQuery.textScalerOf(context),
                ),
            ],
            size: size,
            scale: scale,
          )
        // Nothing to de-collide without labels, so every icon stays exactly on
        // its own dot — nudging them would move the art off the point for
        // no reason, and would draw leader lines to nowhere.
        : [
            for (final entry in labeled)
              _PlacedMarker(entry, Offset.zero, showLabel: false),
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CompassRosePainter(
                    nearby: nearby,
                    placed: markers,
                    showCardinals: showText,
                    primary: scheme.primary,
                    surface: scheme.surface,
                    onSurface: scheme.onSurface,
                  ),
                ),
              ),
              for (final marker in markers)
                _LocationMarker(marker: marker, size: size, scale: scale),
            ],
          ),
        ),
        if (nearest != null) _NearestChip(nearest: nearest),
      ],
    );
  }
}

/// The nearest entry in each 8-wind direction, keeping the nearest-first order.
///
/// [nearbyLocationsProvider] is already sorted by distance, so the first entry
/// seen for a direction is the one to keep and the overall nearest stays first
/// (which is what the chip under the disc reads).
List<NearbyLocation> _nearestPerDirection(List<NearbyLocation> entries) {
  final directions = <String>{};
  return [
    for (final entry in entries)
      if (directions.add(entry.direction)) entry,
  ];
}

/// A marker's resolved placement, once labels have been de-collided.
class _PlacedMarker {
  final NearbyLocation entry;

  /// Radial displacement from the plotted point, to keep this marker's label
  /// clear of the ones already placed. [Offset.zero] when nothing was in the
  /// way, which is the common case away from a town.
  final Offset nudge;

  /// False when no clear placement existed at all: the icon still marks the
  /// spot, but the name is dropped rather than piled onto a neighbour's.
  final bool showLabel;

  const _PlacedMarker(this.entry, this.nudge, {required this.showLabel});
}

/// The two rectangles a marker occupies: its icon, and its name label below.
///
/// Kept apart because the de-collision pass treats them differently. Two labels
/// overlapping is unreadable and so forbidden; a label crossing an *icon* is
/// fine — the label carries a double black shadow precisely so it reads over
/// the art — and two icons overlapping reads as a cluster rather than a bug.
class _MarkerRects {
  final Rect icon;
  final Rect label;

  const _MarkerRects(this.icon, this.label);
}

_MarkerRects _markerRects({
  required Offset anchor,
  required Size labelSize,
  required double iconSize,
  required double overhang,
}) {
  final iconTop = anchor.dy - overhang;
  return _MarkerRects(
    Rect.fromLTWH(anchor.dx - iconSize / 2, iconTop, iconSize, iconSize),
    Rect.fromLTWH(
      anchor.dx - labelSize.width / 2,
      iconTop + iconSize,
      labelSize.width,
      labelSize.height,
    ),
  );
}

/// Places [entries] so that no two name labels overlap.
///
/// Near a town half a dozen gazetteer entries land within a stadion or two of
/// each other, and their label boxes are far wider than the gap between their
/// plotted points — so drawn naively they pile into an unreadable smudge. Each
/// marker is offered its plotted point first, then positions sliding along and
/// then across its own bearing in [_kNudgeStep] increments, and takes the first
/// that clears every label already placed. Nearest-first order means the
/// locations that matter most keep their true position, and the ones pushed
/// around (or, if nothing fits, left as a bare icon) are the far ones.
List<_PlacedMarker> _placeMarkers({
  required List<NearbyLocation> entries,
  required List<Size> labelSizes,
  required double size,
  required double scale,
}) {
  final center = Offset(size / 2, size / 2);
  final iconSize = _kMarkerIconSize * scale;
  final overhang = _kMarkerOverhang * scale;
  final halfGap = _kLabelGap * scale / 2;
  final step = _kNudgeStep * scale;
  final minRadius = size * _kMarkerMinRadiusFraction;

  // Outward room: enough that the icon still sits inside the rose's ring.
  final maxRadius = (size / 2 - 12) - iconSize + overhang;

  final placedLabels = <Rect>[];
  final placedIcons = <Rect>[];
  final placed = <_PlacedMarker>[];

  for (var i = 0; i < entries.length; i++) {
    final base = _markerOffset(entries[i], size);
    final radius = base.distance;
    // A location the player is standing on plots at the minimum radius due
    // north; its ray is that direction rather than an undefined zero vector.
    final ray = radius == 0 ? const Offset(0, -1) : base / radius;
    final tangent = Offset(-ray.dy, ray.dx);

    // Candidate displacements, least first, so the placement chosen is always
    // the smallest distortion. Radial before tangential at equal magnitude.
    final maxTangential = math.min(
      _kMaxTangentialNudge * scale,
      radius * _kMaxTangentialTan,
    );
    final nudges = <Offset>[Offset.zero];
    for (var m = step; m <= _kMaxRadialNudge * scale + 0.001; m += step) {
      nudges
        ..add(ray * m)
        ..add(ray * -m);
      if (m <= maxTangential + 0.001) {
        nudges
          ..add(tangent * m)
          ..add(tangent * -m);
      }
    }

    ({Offset nudge, _MarkerRects rects})? clear, anyClear;

    for (final nudge in nudges) {
      final point = base + nudge;
      if (point.distance < minRadius - 0.001 || point.distance > maxRadius) {
        continue;
      }

      final rects = _markerRects(
        anchor: center + point,
        labelSize: labelSizes[i],
        iconSize: iconSize,
        overhang: overhang,
      );
      final label = rects.label.inflate(halfGap);
      if (placedLabels.any(label.overlaps)) continue;

      final candidate = (nudge: nudge, rects: rects);
      anyClear ??= candidate;
      // Prefer a placement that also leaves the icons alone, but do not insist.
      final touchesIcon = placedIcons.any(rects.label.overlaps) ||
          placedIcons.any(rects.icon.overlaps) ||
          placedLabels.any(rects.icon.overlaps);
      if (!touchesIcon) {
        clear = candidate;
        break;
      }
    }

    final chosen = clear ?? anyClear;
    if (chosen == null) {
      // Genuinely nowhere to put the name — keep the icon on its dot so the
      // place is still marked, and let the nearest-location chip carry names.
      placed.add(_PlacedMarker(entries[i], Offset.zero, showLabel: false));
      placedIcons.add(_markerRects(
        anchor: center + base,
        labelSize: labelSizes[i],
        iconSize: iconSize,
        overhang: overhang,
      ).icon);
    } else {
      placed.add(_PlacedMarker(entries[i], chosen.nudge, showLabel: true));
      placedLabels.add(chosen.rects.label.inflate(halfGap));
      placedIcons.add(chosen.rects.icon);
    }
  }

  return placed;
}

/// Style of a marker's name label.
///
/// Shared with the measuring pass that feeds [_placeMarkers], so the boxes the
/// de-collision reasons about cannot drift from the ones actually painted.
TextStyle _labelStyle(Color color) => TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 12,
      height: 1.1,
      color: color,
      shadows: const [
        Shadow(color: Colors.black, blurRadius: 3),
        Shadow(color: Colors.black, blurRadius: 6),
      ],
    );

/// Size the label of [text] will render at, matching [_LocationMarker]'s [Text]
/// (same style, same width cap, two lines then ellipsis).
Size _measureLabel(String text, TextStyle style, double maxWidth,
    TextScaler textScaler) {
  return (TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 2,
    ellipsis: '…',
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth))
      .size;
}

/// Offset of a nearby location from the center of a [size]-wide compass,
/// north up.
Offset _markerOffset(NearbyLocation entry, double size) {
  final minRadius = size * _kMarkerMinRadiusFraction;
  final maxRadius = size * _kMarkerMaxRadiusFraction;
  final radius = minRadius +
      (entry.distance / kCompassRangeStadia) * (maxRadius - minRadius);
  return Offset(
    math.sin(entry.bearing) * radius,
    -math.cos(entry.bearing) * radius,
  );
}

/// Icon + name label anchored at a location's bearing/distance point, shifted
/// by whatever [_placeMarkers] decided was needed to keep the name readable.
class _LocationMarker extends StatelessWidget {
  final _PlacedMarker marker;
  final double size;
  final double scale;

  const _LocationMarker({
    required this.marker,
    required this.size,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entry = marker.entry;
    final offset = _markerOffset(entry, size) + marker.nudge;
    final markerWidth = _kMarkerWidth * scale;
    final center = size / 2;

    return Positioned(
      left: center + offset.dx - markerWidth / 2,
      top: center + offset.dy - _kMarkerOverhang * scale,
      width: markerWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LocationIcon(kind: entry.location.kind, scale: scale),
          if (marker.showLabel)
            Text(
              entry.location.shortName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _labelStyle(scheme.onSurface),
            ),
        ],
      ),
    );
  }
}

/// Kind icon: the Blender-rendered PNG when available, an emoji until then.
class _LocationIcon extends StatelessWidget {
  final LocationKind kind;
  final double scale;

  const _LocationIcon({required this.kind, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    if (_kRenderedIconKinds.contains(kind)) {
      return Image.asset(
        'assets/images/compass/${kind.name}.png',
        width: _kMarkerIconSize * scale,
        height: _kMarkerIconSize * scale,
        filterQuality: FilterQuality.medium,
      );
    }
    return Text(
      _kKindEmoji[kind] ?? '📍',
      style: TextStyle(fontSize: 24 * scale, height: 1),
    );
  }
}

/// Compact "nearest location" readout under the rose,
/// e.g. "Tantallon · 3 stadia NE".
class _NearestChip extends StatelessWidget {
  final NearbyLocation nearest;

  const _NearestChip({required this.nearest});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final distance = nearest.distance.round();
    final where =
        distance == 0 ? 'here' : '$distance stadia ${nearest.direction}';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surface.withAlpha(200),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withAlpha(60)),
      ),
      child: Text(
        '${nearest.location.shortName} · $where',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          color: scheme.onSurface.withAlpha(220),
        ),
      ),
    );
  }
}

/// Paints the rose itself: translucent disc, range rings, cardinal ticks
/// and letters, the player dot, and one small dot per nearby location
/// (including those beyond the labeled-marker cap).
class _CompassRosePainter extends CustomPainter {
  final List<NearbyLocation> nearby;

  /// The labeled markers and where de-collision put them, so a marker that had
  /// to move can be tied back to its dot with a leader line.
  final List<_PlacedMarker> placed;

  /// Draw the N/E/S/W letters. When false the north tick carries the
  /// orientation on its own, so a text-free disc still reads north-up.
  final bool showCardinals;

  final Color primary;
  final Color surface;
  final Color onSurface;

  _CompassRosePainter({
    required this.nearby,
    required this.placed,
    required this.showCardinals,
    required this.primary,
    required this.surface,
    required this.onSurface,
  });

  static const List<String> _cardinals = ['N', 'E', 'S', 'W'];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringRadius = size.width / 2 - 12;
    final scale = size.width / kCompassSize;

    // Disc + outer ring.
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()..color = surface.withAlpha(190),
    );
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = primary.withAlpha(130),
    );

    // Faint range rings at half range and full range.
    final rangePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = onSurface.withAlpha(24);
    // Radii come from the painted size, so the rings land on the markers at
    // any diameter (the rose renders smaller on phones).
    final minRadius = size.width * _kMarkerMinRadiusFraction;
    final maxRadius = size.width * _kMarkerMaxRadiusFraction;
    canvas.drawCircle(center, minRadius + (maxRadius - minRadius) / 2, rangePaint);
    canvas.drawCircle(center, maxRadius, rangePaint);

    // 16-wind ticks; the 8 major ones longer and brighter. Without the cardinal
    // letters the north tick is the only thing saying which way is up, so it
    // reaches further in and is drawn at full strength.
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final isMajor = i.isEven;
      final isNorth = i == 0 && !showCardinals;
      final inner =
          ringRadius - (isNorth ? 24 * scale : (isMajor ? 15 : 8));
      final direction = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(
        center + direction * inner,
        center + direction * ringRadius,
        Paint()
          ..strokeWidth = isNorth ? 3.4 : (isMajor ? 2.6 : 1.6)
          ..color = primary.withAlpha(isNorth ? 255 : (isMajor ? 150 : 70)),
      );
    }

    // Cardinal letters just inside the ticks.
    for (var i = 0; showCardinals && i < 4; i++) {
      final angle = i * math.pi / 2;
      final position = center +
          Offset(math.sin(angle), -math.cos(angle)) * (ringRadius - 30);
      final painter = TextPainter(
        text: TextSpan(
          text: _cardinals[i],
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: i == 0 ? primary : onSurface.withAlpha(150),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    }

    // Player dot at the center. The radii scale with the disc, with a floor so
    // they stay visible: left absolute they swell to blobs on the phone rose,
    // where the disc is half the size but every dot would still be full width.
    canvas.drawCircle(
      center,
      math.max(5.5 * scale, 3.0),
      Paint()..color = primary,
    );
    canvas.drawCircle(
      center,
      math.max(10 * scale, 5.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = primary.withAlpha(90),
    );

    // Leader lines, for the markers de-collision had to move off their point.
    // Drawn before the dots so the dot stays the brightest thing on the ray.
    final iconRadius = _kMarkerIconSize * scale / 2;
    final leaderPaint = Paint()
      ..strokeWidth = 1.2
      ..color = primary.withAlpha(110);
    for (final marker in placed) {
      final travelled = marker.nudge.distance;
      // A marker nudged less than its own icon is still sitting on its dot,
      // so there is nothing to lead the eye across.
      if (travelled <= iconRadius + 6) continue;
      final dot = center + _markerOffset(marker.entry, size.width);
      final along = marker.nudge / travelled;
      // Start clear of the dot, stop at the edge of the icon it leads to.
      canvas.drawLine(
        dot + along * 5.5,
        dot + marker.nudge - along * iconRadius,
        leaderPaint,
      );
    }

    // One dot per nearby location — the true plotted point, and the only trace
    // of locations beyond the label cap.
    final dotPaint = Paint()..color = primary.withAlpha(210);
    final dotRadius = math.max(3.6 * scale, 2.0);
    for (final entry in nearby) {
      canvas.drawCircle(
          center + _markerOffset(entry, size.width), dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_CompassRosePainter oldDelegate) =>
      oldDelegate.nearby != nearby ||
      oldDelegate.placed != placed ||
      oldDelegate.showCardinals != showCardinals ||
      oldDelegate.primary != primary ||
      oldDelegate.surface != surface ||
      oldDelegate.onSurface != onSurface;
}
