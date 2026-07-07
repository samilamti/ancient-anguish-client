import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/known_location.dart';
import '../../../providers/compass_provider.dart';
import '../../../providers/game_state_provider.dart';

/// Diameter of the compass disc.
const double _kCompassSize = 216;

/// Markers are plotted between these radii: touching distance at the
/// center, [kCompassRangeStadia] at the outer edge.
const double _kMarkerMinRadius = 16;
const double _kMarkerMaxRadius = 76;

/// At most this many nearby locations get an icon + name label; anything
/// farther is still drawn as a small dot on the rose.
const int _kMaxLabeledMarkers = 6;

/// Blender-rendered icons that exist under assets/images/compass/. Kinds
/// not listed here fall back to an emoji glyph until their art lands.
const Set<LocationKind> _kRenderedIconKinds = {};

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
class CompassOverlay extends ConsumerWidget {
  const CompassOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCoordinates =
        ref.watch(gameStateProvider.select((s) => s.hasCoordinates));
    if (!hasCoordinates) return const SizedBox.shrink();

    final nearby = ref.watch(nearbyLocationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final nearest = nearby.isEmpty ? null : nearby.first;

    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _kCompassSize,
            height: _kCompassSize,
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
                for (final entry in nearby.take(_kMaxLabeledMarkers))
                  _LocationMarker(entry: entry),
              ],
            ),
          ),
          if (nearest != null) _NearestChip(nearest: nearest),
        ],
      ),
    );
  }
}

/// Offset of a nearby location from the compass center, north up.
Offset _markerOffset(NearbyLocation entry) {
  final radius = _kMarkerMinRadius +
      (entry.distance / kCompassRangeStadia) *
          (_kMarkerMaxRadius - _kMarkerMinRadius);
  return Offset(
    math.sin(entry.bearing) * radius,
    -math.cos(entry.bearing) * radius,
  );
}

/// Icon + name label anchored at a location's bearing/distance point.
class _LocationMarker extends StatelessWidget {
  final NearbyLocation entry;

  const _LocationMarker({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offset = _markerOffset(entry);
    const markerWidth = 72.0;
    final center = _kCompassSize / 2;

    return Positioned(
      left: center + offset.dx - markerWidth / 2,
      top: center + offset.dy - 10,
      width: markerWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LocationIcon(kind: entry.location.kind),
          Text(
            entry.location.shortName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 9,
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

  const _LocationIcon({required this.kind});

  @override
  Widget build(BuildContext context) {
    if (_kRenderedIconKinds.contains(kind)) {
      return Image.asset(
        'assets/images/compass/${kind.name}.png',
        width: 22,
        height: 22,
        filterQuality: FilterQuality.medium,
      );
    }
    return Text(
      _kKindEmoji[kind] ?? '📍',
      style: const TextStyle(fontSize: 13, height: 1),
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
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surface.withAlpha(200),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withAlpha(60)),
      ),
      child: Text(
        '${nearest.location.shortName} · $where',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
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
    final ringRadius = size.width / 2 - 8;

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
        ..strokeWidth = 1.5
        ..color = primary.withAlpha(130),
    );

    // Faint range rings at half range and full range.
    final rangePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = onSurface.withAlpha(24);
    final halfRadius = _kMarkerMinRadius +
        (_kMarkerMaxRadius - _kMarkerMinRadius) / 2;
    canvas.drawCircle(center, halfRadius, rangePaint);
    canvas.drawCircle(center, _kMarkerMaxRadius, rangePaint);

    // 16-wind ticks; the 8 major ones longer and brighter.
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final isMajor = i.isEven;
      final inner = ringRadius - (isMajor ? 8 : 4);
      final direction = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(
        center + direction * inner,
        center + direction * ringRadius,
        Paint()
          ..strokeWidth = isMajor ? 1.6 : 1
          ..color = primary.withAlpha(isMajor ? 150 : 70),
      );
    }

    // Cardinal letters just inside the ticks.
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final position = center +
          Offset(math.sin(angle), -math.cos(angle)) * (ringRadius - 17);
      final painter = TextPainter(
        text: TextSpan(
          text: _cardinals[i],
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
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
    canvas.drawCircle(center, 3.5, Paint()..color = primary);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = primary.withAlpha(90),
    );

    // One dot per nearby location — the anchor point the labeled markers
    // sit on, and the only trace of locations beyond the label cap.
    final dotPaint = Paint()..color = primary.withAlpha(210);
    for (final entry in nearby) {
      canvas.drawCircle(center + _markerOffset(entry), 2.4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_CompassRosePainter oldDelegate) =>
      oldDelegate.nearby != nearby ||
      oldDelegate.primary != primary ||
      oldDelegate.surface != surface ||
      oldDelegate.onSurface != onSurface;
}
