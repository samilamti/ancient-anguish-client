import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/battle_filter_mode.dart';
import '../../../models/battle_stats.dart';
import '../../../providers/battle_stats_provider.dart';

/// Combat panel shown under [BattleFilterMode.hud].
///
/// It has to earn the combat text it replaced, so it carries both halves of
/// what scrolling combat output told the player: the running tallies (which
/// scrolling text never made legible anyway) and the latest line verbatim.
///
/// Appears when a fight starts and lingers for `BattleNotifier.battleTimeout`
/// after the last exchange — long enough that the kill line is still on screen
/// when the player looks up.
///
/// Docked rather than floating — see [BattleHudDock] for why.
///
/// **Stateful, with its own second-timer and pulse.** It was deliberately
/// tickerless at first: combat lines arrive several times a second, so a live
/// fight refreshed the elapsed readout on its own. That works while blows are
/// landing and stalls the moment there is a lull mid-fight — the clock simply
/// stops until the next hit — so the time is now driven locally, once a second.
/// Both the timer and the pulse run *only while the fight is active*, so an
/// idle HUD schedules nothing at all (which is also what keeps widget tests
/// from tripping over a pending timer).
class BattleHud extends ConsumerStatefulWidget {
  const BattleHud({super.key});

  /// Fixed width so the tallies don't reflow on every round. Wide enough for
  /// the spelled-out labels ("accuracy", "evade") next to three-digit counts.
  static const double width = 300;

  /// One breath of the border pulse, each direction.
  static const Duration pulsePeriod = Duration(milliseconds: 900);

  @override
  ConsumerState<BattleHud> createState() => _BattleHudState();
}

class _BattleHudState extends ConsumerState<BattleHud>
    with SingleTickerProviderStateMixin {
  /// Ticks the elapsed readout. Null whenever no fight is running, so the widget
  /// costs nothing when idle.
  Timer? _clock;

  late final AnimationController _pulse = AnimationController(
    duration: BattleHud.pulsePeriod,
    vsync: this,
  );

  @override
  void dispose() {
    _clock?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Starts or stops the clock and the pulse to match [active].
  ///
  /// Called from build rather than an effect, but only ever *schedules* work —
  /// the setState is inside the timer callback, never during this build.
  void _syncAnimations({required bool active}) {
    if (active) {
      _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _clock?.cancel();
      _clock = null;
      if (_pulse.isAnimating) {
        _pulse.stop();
        _pulse.value = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(battleStatsProvider);
    // The panel stays up while the tallies are still worth reading — i.e.
    // until a fight has actually started. `active` alone would pop it away the
    // instant combat went quiet, hiding the outcome.
    if (stats.startedAt == null) {
      _syncAnimations(active: false);
      return const SizedBox.shrink();
    }
    _syncAnimations(active: stats.active);

    final scheme = Theme.of(context).colorScheme;
    // Local clock, so the elapsed time advances through a lull instead of
    // freezing until the next blow. It still stops when the fight does, leaving
    // the fight's final length on screen.
    final elapsed = stats.elapsedAt(ref.read(clockProvider)());

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // Pulse the border rather than the whole panel: the text has to stay
        // readable while it breathes.
        final pulseAlpha = stats.active
            ? (110 + 110 * _pulse.value).round()
            : 60;
        return Container(
          width: BattleHud.width,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface.withAlpha(stats.active ? 238 : 200),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: stats.active
                  ? const Color(0xFFCC4444).withAlpha(pulseAlpha)
                  : scheme.primary.withAlpha(60),
              width: stats.active ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(90),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(stats: stats, elapsed: elapsed),
          const SizedBox(height: 6),
          _TallyRow(
            label: 'You',
            hits: stats.hitsDealt,
            misses: stats.missesDealt,
            percent: stats.accuracy,
            percentLabel: 'accuracy',
            accent: scheme.primary,
          ),
          // "Target", not "Taken": the row is what the target managed against
          // you — it hit this often, missed that often, and you evaded N%.
          _TallyRow(
            label: 'Target',
            hits: stats.hitsTaken,
            misses: stats.missesAgainst,
            percent: stats.evasion,
            percentLabel: 'evade',
            accent: const Color(0xFFCC4444),
          ),
          if (stats.hpNow != null) ...[
            const SizedBox(height: 4),
            _VitalsRow(stats: stats),
          ],
          if (stats.latestLine != null) ...[
            const SizedBox(height: 6),
            Divider(height: 1, color: scheme.onSurface.withAlpha(30)),
            const SizedBox(height: 5),
            Text(
              stats.latestLine!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10.5,
                height: 1.25,
                color: scheme.onSurface.withAlpha(190),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reserves layout space for [BattleHud] beneath the terminal instead of
/// floating it over the output.
///
/// The terminal is bottom-anchored, so an overlay panel covers precisely the
/// newest lines — the ones the player is reading. Docking the panel as a
/// sibling below the terminal means the tail of the output slides up to make
/// room and the last received line stays visible for the whole fight, with no
/// height measurement to keep in sync.
///
/// Fades and grows the panel in as a fight starts, and back out as it ends —
/// costing no vertical space at all in between.
///
/// **One controller drives both the opacity and the reserved height**, which is
/// what makes the fade-out possible: the panel has to keep its space while it
/// fades and give it up afterwards, and a pair of implicit animations
/// (`AnimatedOpacity` + `AnimatedSize`) can't express that ordering — an
/// opacity change doesn't affect layout, so the height would collapse before
/// the fade began, or not at all. `SizeTransition` also gives a free fade-in
/// from a genuine zero, which `AnimatedOpacity` cannot: it animates on
/// *change*, so a first build at opacity 1 just appears.
///
/// Visibility follows [BattleStats.active], i.e. the panel leaves ~5s
/// (`battleTimeout`) after the last exchange. Before v6.36 it keyed off
/// `startedAt`, which is never cleared in normal play — so the HUD stayed on
/// screen forever after the first fight of a session. The outcome is still
/// readable afterwards because resolution lines are never filtered out of the
/// terminal.
class BattleHudDock extends ConsumerStatefulWidget {
  const BattleHudDock({super.key});

  /// Long enough to read as a fade rather than a flicker, short enough not to
  /// delay the first combat line the player is waiting for.
  static const Duration fadeDuration = Duration(milliseconds: 220);

  @override
  ConsumerState<BattleHudDock> createState() => _BattleHudDockState();
}

class _BattleHudDockState extends ConsumerState<BattleHudDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: BattleHudDock.fadeDuration,
    vsync: this,
    // Mounting mid-fight (the player switches the mode on during combat)
    // should show the panel, not animate it in from nothing.
    value: ref.read(battleStatsProvider).active ? 1 : 0,
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Driven from a listener rather than the build body: starting an animation
    // during build schedules a layout change from inside layout.
    ref.listen(battleStatsProvider.select((s) => s.active), (_, active) {
      if (active) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });

    return SizeTransition(
      sizeFactor: _curve,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _curve,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 4),
            child: BattleHud(),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final BattleStats stats;
  final Duration? elapsed;

  const _Header({required this.stats, required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rounds = stats.rounds;

    return Row(
      children: [
        Icon(
          Icons.gavel,
          size: 13,
          color: const Color(0xFFCC4444)
              .withAlpha(stats.active ? 230 : 140),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            stats.target ?? 'In combat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        if (stats.resolutions > 0)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              '☠ ${stats.resolutions}',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                color: scheme.onSurface.withAlpha(150),
              ),
            ),
          ),
        // Spelled out rather than "r15": the HUD is what the player reads
        // instead of the combat text, so it should not need decoding.
        Text(
          [
            if (rounds > 0) 'round $rounds',
            if (elapsed != null) _formatElapsed(elapsed!),
          ].join('  '),
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10,
            color: scheme.onSurface.withAlpha(130),
          ),
        ),
      ],
    );
  }

  static String _formatElapsed(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// One `label  hits / misses  (pct)` line of the scoreboard.
class _TallyRow extends StatelessWidget {
  final String label;
  final int hits;
  final int misses;
  final int? percent;
  final String percentLabel;
  final Color accent;

  const _TallyRow({
    required this.label,
    required this.hits,
    required this.misses,
    required this.percent,
    required this.percentLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final numberStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 11,
      color: scheme.onSurface.withAlpha(210),
    );
    final unitStyle = numberStyle.copyWith(
      fontSize: 9.5,
      color: scheme.onSurface.withAlpha(120),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: accent.withAlpha(210),
              ),
            ),
          ),
          // One ellipsizing Text rather than five siblings in the Row: a row of
          // independently-sized Texts overflows as soon as the numbers reach
          // three digits or the font metrics differ from the ones it was
          // eyeballed against, and the padding here leaves only ~246px.
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$hits', style: numberStyle),
                TextSpan(text: ' hit', style: unitStyle),
                TextSpan(text: '  $misses', style: numberStyle),
                TextSpan(text: ' miss', style: unitStyle),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (percent != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '$percent% $percentLabel',
                maxLines: 1,
                style: numberStyle.copyWith(
                  fontSize: 10,
                  color: accent.withAlpha(200),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `HP 82  SP 79   -14` — the vitals the gagged `HP:/SP:` lines carried.
class _VitalsRow extends StatelessWidget {
  final BattleStats stats;

  const _VitalsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 11,
      color: scheme.onSurface.withAlpha(210),
    );
    final labelStyle = baseStyle.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: scheme.onSurface.withAlpha(120),
    );
    final lost = stats.hpLost;

    return Row(
      children: [
        Text('HP ', style: labelStyle),
        Text('${stats.hpNow}', style: baseStyle),
        if (stats.spNow != null) ...[
          const SizedBox(width: 10),
          Text('SP ', style: labelStyle),
          Text('${stats.spNow}', style: baseStyle),
        ],
        const Spacer(),
        if (lost != null && lost != 0)
          Text(
            lost > 0 ? '-$lost' : '+${-lost}',
            style: baseStyle.copyWith(
              fontSize: 10,
              color: lost > 0
                  ? const Color(0xFFCC4444).withAlpha(220)
                  : const Color(0xFF55AA55).withAlpha(220),
            ),
          ),
      ],
    );
  }
}
