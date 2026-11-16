import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/kata_provider.dart';
import '../../../providers/local_features_provider.dart';
import '../../../providers/settings_provider.dart';
import '../social/panel_title_bar.dart';

/// The floating Katas window, styled like the Social Windows: an on/off
/// switch and ten slots, one per second of a fight. The slot firing right now
/// is highlighted while a fight is on.
class KataWindowOverlay extends ConsumerWidget {
  const KataWindowOverlay({super.key});

  static const width = 300.0;
  static const maxHeight = 560.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(localFeaturesAvailableProvider).value ?? false;
    final window = ref.watch(kataWindowProvider);
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
          child: const _KataPanel(),
        ),
      ),
    ]);
  }
}

class _KataPanel extends ConsumerWidget {
  const _KataPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kata = ref.watch(kataProvider);
    final slots = ref.watch(settingsProvider.select((s) => s.kataSlots));
    final window = ref.read(kataWindowProvider.notifier);

    final String subtitle;
    if (kata.performing) {
      subtitle = 'In battle · second ${kata.slot}';
    } else if (kata.armed) {
      subtitle = 'Waiting for a fight';
    } else {
      subtitle = 'Runs slot 1 at the first blow, one slot a second, '
          'and loops until the fight ends.';
    }

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
            title: 'Katas',
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
                  secondary: Icon(Icons.sports_martial_arts,
                      color: kata.armed ? Colors.green : null),
                  title: Text(kata.armed ? 'On' : 'Off'),
                  subtitle: Text(subtitle),
                  value: kata.armed,
                  onChanged: (_) => ref.read(kataProvider.notifier).toggle(),
                ),
                for (var i = 0; i < AppSettings.kataSlotCount; i++)
                  _KataSlotField(
                    index: i,
                    value: i < slots.length ? slots[i] : '',
                    firing: kata.performing && kata.slot == i + 1,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Empty slots wait a second. Empty slots after the last '
                    'action are skipped, so the Kata loops sooner.',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withAlpha(150)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One numbered slot. Saves as you type.
class _KataSlotField extends ConsumerStatefulWidget {
  const _KataSlotField({
    required this.index,
    required this.value,
    required this.firing,
  });

  final int index;
  final String value;
  final bool firing;

  @override
  ConsumerState<_KataSlotField> createState() => _KataSlotFieldState();
}

class _KataSlotFieldState extends ConsumerState<_KataSlotField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _KataSlotField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only adopt an outside change; never fight the player's own typing.
    if (widget.value != _controller.text.trim()) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = widget.index + 1;
    return Container(
      color: widget.firing ? Colors.green.withAlpha(50) : null,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Row(children: [
        SizedBox(
          width: 32,
          child: Text('${n}s',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: widget.firing ? FontWeight.bold : null,
                color: widget.firing ? Colors.green : null,
              )),
        ),
        Expanded(
          child: TextField(
            key: ValueKey('kata-slot-$n'),
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'nothing',
            ),
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setKataSlot(widget.index, v),
          ),
        ),
      ]),
    );
  }
}
