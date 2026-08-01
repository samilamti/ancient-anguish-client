import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/compass_provider.dart';
import 'compass_overlay.dart';

/// The mobile face of the navigation compass: one line naming the nearest
/// known location, with an arrow pointing at its true bearing.
///
/// The full rose is 432px across — wider than a phone screen and taller than
/// the terminal it would float over — and it appears and vanishes as the player
/// steps in and out of buildings, so an always-on disc would both cost a third
/// of the usable height and jump the layout. This strip is ~28px, answers the
/// question you ask most often ("which way, how far"), and taps through to the
/// whole rose when you actually need to see several destinations at once.
///
/// Hides itself when nothing is in range, which is the same condition
/// [CompassOverlay] hides on — indoors, not logged in, coordinates unknown.
class CompassStrip extends ConsumerWidget {
  const CompassStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(nearbyLocationsProvider);
    if (nearby.isEmpty) return const SizedBox.shrink();

    final nearest = nearby.first;
    final scheme = Theme.of(context).colorScheme;
    final distance = nearest.distance.round();
    final others = nearby.length - 1;

    return Material(
      color: scheme.surface.withAlpha(230),
      child: InkWell(
        onTap: () => showCompassRose(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.primary.withAlpha(40)),
            ),
          ),
          child: Row(
            children: [
              _BearingArrow(bearing: nearest.bearing, color: scheme.primary),
              const SizedBox(width: 6),
              // The name and its distance are one group that takes all the
              // slack, so the leftover space lands *after* the distance rather
              // than being split with a Spacer — a bare `Flexible` name plus a
              // `Spacer` both claim flex, which truncated "Giants' convention"
              // to "Giants' conventi…" with empty space sitting beside it.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        nearest.location.shortName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      distance == 0
                          ? 'here'
                          : '$distance st ${nearest.direction}',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        color: scheme.onSurface.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
              // Earns the tap: says there is more to see, and how much.
              if (others > 0)
                Text(
                  '+$others',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    color: scheme.onSurface.withAlpha(120),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.explore,
                size: 15,
                color: scheme.primary.withAlpha(180),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A triangle rotated to [bearing] (radians, 0 = north, clockwise), so the
/// direction is readable at a glance without parsing "NE".
class _BearingArrow extends StatelessWidget {
  final double bearing;
  final Color color;

  const _BearingArrow({required this.bearing, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      // Icons.navigation points north already, and Flutter's rotation is
      // clockwise for positive angles — the same convention as the bearing.
      angle: bearing,
      child: Icon(Icons.navigation, size: 15, color: color),
    );
  }
}

/// Opens the full compass rose over the current screen, sized to fit.
///
/// A dialog rather than a bottom sheet: the rose is square and wants to be
/// centred, and the barrier gives tap-anywhere-to-dismiss plus Escape for free.
Future<void> showCompassRose(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      final media = MediaQuery.of(dialogContext);
      // Half of what would fit: filling the screen was too large for a glance
      // (Sami, 2026-07-31). It can afford to be small because the phone rose
      // carries no text and at most one marker per direction — it reads as a
      // radar, not a map, and the strip underneath already names the nearest.
      final available = (media.size.shortestSide - 32) / 2;
      final size = available.clamp(140.0, kCompassSize / 2);

      return GestureDetector(
        // Tapping the rose itself dismisses too — it is a glance, not a screen.
        onTap: () => Navigator.of(dialogContext).pop(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: CompassRose(
              size: size,
              showText: false,
              nearestPerDirection: true,
              // One per direction already caps it at eight, so this is just a
              // backstop rather than the thing doing the thinning.
              maxLabeledMarkers: 8,
            ),
          ),
        ),
      );
    },
  );
}
