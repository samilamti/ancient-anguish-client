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

  /// How many locations get an icon + name. Worth lowering along with [size]:
  /// the labels crowd the disc, and six of them on a phone-sized rose overlap.
  final int maxLabeledMarkers;

  const CompassRose({
    super.key,
    this.size = kCompassSize,
    this.maxLabeledMarkers = kMaxLabeledMarkers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(nearbyLocationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final nearest = nearby.isEmpty ? null : nearby.first;
    final scale = size / kCompassSize;

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
                    primary: scheme.primary,
                    surface: scheme.surface,
                    onSurface: scheme.onSurface,
                  ),
                ),
              ),
              for (final entry in nearby.take(maxLabeledMarkers))
                _LocationMarker(entry: entry, size: size, scale: scale),
            ],
          ),
        ),
        if (nearest != null) _NearestChip(nearest: nearest),
      ],
    );
  }
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

/// Icon + name label anchored at a location's bearing/distance point.
class _LocationMarker extends StatelessWidget {
  final NearbyLocation entry;
  final double size;
  final double scale;

  const _LocationMarker({
    required this.entry,
    required this.size,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offset = _markerOffset(entry, size);
    final markerWidth = _kMarkerWidth * scale;
    final center = size / 2;

    return Positioned(
      left: center + offset.dx - markerWidth / 2,
      top: center + offset.dy - 18 * scale,
      width: markerWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LocationIcon(kind: entry.location.kind, scale: scale),
          Text(
            entry.location.shortName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              height: 1.1,
              color: scheme.onSurface,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 3),
                Shadow(color: Colors.black, blurRadius: 6),
              ],
            ),
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
  final Color primary;
  final Color surface;
  final Color onSurface;

  _CompassRosePainter({
    required this.nearby,
    required this.primary,
    required this.surface,
    required this.onSurface,
  });

  static const List<String> _cardinals = ['N', 'E', 'S', 'W'];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringRadius = size.width / 2 - 12;

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

    // 16-wind ticks; the 8 major ones longer and brighter.
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final isMajor = i.isEven;
      final inner = ringRadius - (isMajor ? 15 : 8);
      final direction = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(
        center + direction * inner,
        center + direction * ringRadius,
        Paint()
          ..strokeWidth = isMajor ? 2.6 : 1.6
          ..color = primary.withAlpha(isMajor ? 150 : 70),
      );
    }

    // Cardinal letters just inside the ticks.
    for (var i = 0; i < 4; i++) {
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

    // Player dot at the center.
    canvas.drawCircle(center, 5.5, Paint()..color = primary);
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = primary.withAlpha(90),
    );

    // One dot per nearby location — the anchor point the labeled markers
    // sit on, and the only trace of locations beyond the label cap.
    final dotPaint = Paint()..color = primary.withAlpha(210);
    for (final entry in nearby) {
      canvas.drawCircle(center + _markerOffset(entry, size.width), 3.6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_CompassRosePainter oldDelegate) =>
      oldDelegate.nearby != nearby ||
      oldDelegate.primary != primary ||
      oldDelegate.surface != surface ||
      oldDelegate.onSurface != onSurface;
}
