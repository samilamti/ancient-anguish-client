import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auto_hunt_provider.dart';
import '../../../providers/local_features_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/hunt/auto_hunt_engine.dart';
import '../social/panel_title_bar.dart';

/// The floating Auto Hunt window, styled like the Social Windows: what to
/// attack, what to walk away from, and how slowly to wander. Opens by itself
/// when Auto Hunt starts, so its settings are on screen while it runs, and
/// can be opened from the Settings drawer to set up a hunt first.
class AutoHuntWindowOverlay extends ConsumerWidget {
  const AutoHuntWindowOverlay({super.key});

  static const width = 320.0;
  static const maxHeight = 460.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(localFeaturesAvailableProvider).value ?? false;
    final window = ref.watch(autoHuntWindowProvider);
    if (!available || !window.open) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final w = width.clamp(200.0, size.width - 16).toDouble();
    // Keep the title bar reachable however far it was dragged.
    final left = window.position.dx.clamp(0.0, size.width - w).toDouble();
    final top = window.position.dy.clamp(0.0, size.height - 40).toDouble();

    return Stack(children: [
      Positioned(
        left: left,
        top: top,
        width: w,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight.clamp(120.0, size.height - top).toDouble(),
          ),
          child: const _AutoHuntPanel(),
        ),
      ),
    ]);
  }
}

class _AutoHuntPanel extends ConsumerWidget {
  const _AutoHuntPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hunt = ref.watch(autoHuntProvider);
    final targets =
        ref.watch(settingsProvider.select((s) => s.autoHuntTargets));
    final avoid = ref.watch(settingsProvider.select((s) => s.autoHuntAvoid));
    final step =
        ref.watch(settingsProvider.select((s) => s.autoHuntStepSeconds));
    final settings = ref.read(settingsProvider.notifier);
    final window = ref.read(autoHuntWindowProvider.notifier);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitleBar(
            title: 'Auto Hunt',
            isDocked: false,
            isTabbed: false,
            onClose: window.close,
            onPanStart: (_) {},
            onPanUpdate: (d) => window.moveBy(d.delta),
            onPanEnd: (_) {},
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                SwitchListTile(
                  dense: true,
                  secondary: Icon(Icons.travel_explore,
                      color: hunt.running ? Colors.green : null),
                  title: Text(hunt.running ? 'Hunting' : 'Stopped'),
                  subtitle: Text(hunt.running
                      ? hunt.status
                      : 'Walks ${AutoHuntEngine.allowedDirections.join('/')}, '
                          'kills targets, leaves rooms with anything to '
                          'avoid.'),
                  value: hunt.running,
                  onChanged: (_) =>
                      ref.read(autoHuntProvider.notifier).toggle(),
                ),
                _PhraseList(
                  title: 'Targets',
                  hint: 'e.g. spider',
                  help: 'Attacked with "kill" when seen in a room.',
                  icon: Icons.gps_fixed,
                  phrases: targets,
                  onChanged: settings.setAutoHuntTargets,
                ),
                _PhraseList(
                  title: 'Avoid',
                  hint: 'e.g. hill giant',
                  help: 'A room holding one of these is left at once, back '
                      'the way the hunter came when it can.',
                  icon: Icons.block,
                  phrases: avoid,
                  onChanged: settings.setAutoHuntAvoid,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(children: [
                    const Icon(Icons.timer_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text('Pause', style: theme.textTheme.titleSmall),
                    Expanded(
                      child: Slider(
                        value: step.toDouble(),
                        min: 2,
                        max: 30,
                        divisions: 28,
                        label: '${step}s',
                        onChanged: (v) =>
                            settings.setAutoHuntStepSeconds(v.round()),
                      ),
                    ),
                    Text('${step}s', style: theme.textTheme.bodyMedium),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A heading, chips for each phrase, and a field to add another.
class _PhraseList extends StatefulWidget {
  const _PhraseList({
    required this.title,
    required this.hint,
    required this.help,
    required this.icon,
    required this.phrases,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final String help;
  final IconData icon;
  final List<String> phrases;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_PhraseList> createState() => _PhraseListState();
}

class _PhraseListState extends State<_PhraseList> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onChanged([...widget.phrases, text]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(widget.icon, size: 18),
            const SizedBox(width: 8),
            Text(widget.title, style: theme.textTheme.titleSmall),
          ]),
          const SizedBox(height: 4),
          Text(widget.help,
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withAlpha(150))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in widget.phrases)
                InputChip(
                  label: Text(p),
                  onDeleted: () => widget.onChanged(
                      [for (final q in widget.phrases) if (q != p) q]),
                ),
            ],
          ),
          TextField(
            controller: _controller,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: widget.hint,
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add',
                onPressed: _add,
              ),
            ),
            onSubmitted: (_) => _add(),
          ),
        ],
      ),
    );
  }
}
