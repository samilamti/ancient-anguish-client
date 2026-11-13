import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auto_hunt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/hunt/auto_hunt_engine.dart';
import '../widgets/common/escape_dismiss.dart';

/// Local-only Auto Hunt: what to attack, what to walk away from, and how
/// slowly to wander between rooms.
class AutoHuntSettingsScreen extends ConsumerWidget {
  const AutoHuntSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hunt = ref.watch(autoHuntProvider);
    final targets =
        ref.watch(settingsProvider.select((s) => s.autoHuntTargets));
    final avoid = ref.watch(settingsProvider.select((s) => s.autoHuntAvoid));
    final step =
        ref.watch(settingsProvider.select((s) => s.autoHuntStepSeconds));
    final settings = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return EscapeDismiss(
      child: Scaffold(
        appBar: AppBar(title: const Text('Auto Hunt')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.travel_explore),
              title: const Text('Auto Hunt'),
              subtitle: Text(hunt.running
                  ? hunt.status
                  : 'Walks ${AutoHuntEngine.allowedDirections.join('/')}, '
                      'kills targets, leaves rooms with anything to avoid.'),
              value: hunt.running,
              onChanged: (_) => ref.read(autoHuntProvider.notifier).toggle(),
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
              help: 'Any room holding one of these is left at once, back '
                  'the way the hunter came when it can.',
              icon: Icons.block,
              phrases: avoid,
              onChanged: settings.setAutoHuntAvoid,
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Pause between rooms'),
              subtitle: Slider(
                value: step.toDouble(),
                min: 2,
                max: 30,
                divisions: 28,
                label: '${step}s',
                onChanged: (v) => settings.setAutoHuntStepSeconds(v.round()),
              ),
              trailing: Text('${step}s', style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
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
