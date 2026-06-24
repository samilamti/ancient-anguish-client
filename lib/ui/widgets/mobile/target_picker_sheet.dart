import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/common_targets_provider.dart';
import '../../../providers/recent_words_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../screens/kill_alias_designer_screen.dart';

/// Modal bottom sheet listing recent MUD words for a quick-command target.
///
/// Shown when the user taps a `selectTarget: true` quick command (e.g. Kill).
/// Returns the chosen word via Navigator.pop, or `null` if dismissed.
class TargetPickerSheet extends ConsumerStatefulWidget {
  final String commandLabel;

  const TargetPickerSheet({super.key, required this.commandLabel});

  /// Presents the sheet and resolves with the chosen word, or `null`.
  static Future<String?> show(BuildContext context, {required String commandLabel}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TargetPickerSheet(commandLabel: commandLabel),
    );
  }

  @override
  ConsumerState<TargetPickerSheet> createState() => _TargetPickerSheetState();
}

class _TargetPickerSheetState extends ConsumerState<TargetPickerSheet> {
  static const int _maxResults = 50;
  final TextEditingController _filterController = TextEditingController();
  String _prefix = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  /// Pins whatever is currently typed in the filter field as a custom target,
  /// then clears the field. Used by the add button and the keyboard submit.
  void _addCurrentAsPinned() {
    final text = _filterController.text.trim();
    if (text.isEmpty) return;
    ref.read(settingsProvider.notifier).addPinnedTarget(text);
    _filterController.clear();
    setState(() => _prefix = '');
  }

  /// Opens the alias designer for [word]. Does not pin the target.
  void _openCustomise(String word) {
    openKillAliasDesigner(context, target: word);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final autoTargets = ref.watch(commonTargetsProvider);
    final pinned = ref.watch(settingsProvider.select((s) => s.pinnedTargets));
    final mib = ref.watch(settingsProvider.select((s) => s.mobileInput));
    final viewInsets = MediaQuery.of(context).viewInsets;

    // Pinned targets sit at the top regardless of normal ordering; the
    // auto-identified list follows with any pinned entries removed. Both honour
    // the current filter; only the auto list is capped at [_maxResults].
    final pinnedSet = pinned.toSet();
    final pinnedMatches = completionsFor(pinned, _prefix).toList();
    final otherMatches = completionsFor(autoTargets, _prefix)
        .where((w) => !pinnedSet.contains(w))
        .take(_maxResults)
        .toList();
    final totalCount = pinnedMatches.length + otherMatches.length;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '${widget.commandLabel} target',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '$totalCount match${totalCount == 1 ? '' : 'es'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _filterController,
                        autofocus: false,
                        textInputAction: TextInputAction.done,
                        autocorrect: mib.autocorrect,
                        enableSuggestions: mib.enableSuggestions,
                        smartDashesType: mib.smartDashesType,
                        smartQuotesType: mib.smartQuotesType,
                        decoration: const InputDecoration(
                          hintText: 'Filter or add target…',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                        ),
                        style: const TextStyle(fontFamily: 'JetBrainsMono'),
                        onChanged: (value) =>
                            setState(() => _prefix = value.trim()),
                        onSubmitted: (_) => _addCurrentAsPinned(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Pin target',
                      onPressed: _addCurrentAsPinned,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: totalCount == 0
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _prefix.isEmpty
                                ? 'No targets available.'
                                : 'No matches for "$_prefix".',
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final word in pinnedMatches)
                            _PinnedTargetTile(
                              word: word,
                              theme: theme,
                              onTap: () => Navigator.of(context).pop(word),
                              onCustomise: () => _openCustomise(word),
                              onRemove: () => ref
                                  .read(settingsProvider.notifier)
                                  .removePinnedTarget(word),
                            ),
                          if (pinnedMatches.isNotEmpty &&
                              otherMatches.isNotEmpty)
                            const Divider(height: 1),
                          for (final word in otherMatches)
                            ListTile(
                              dense: true,
                              title: Text(
                                word,
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.tune, size: 18),
                                tooltip: 'Customise',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _openCustomise(word),
                              ),
                              onTap: () => Navigator.of(context).pop(word),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pinned target row in the Kill picker. A pin icon and primary-coloured,
/// semi-bold label mark it as user-pinned (distinct from auto-identified
/// targets), with a trailing button to unpin it. Tapping the row chooses it.
class _PinnedTargetTile extends StatelessWidget {
  final String word;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onCustomise;
  final VoidCallback onRemove;

  const _PinnedTargetTile({
    required this.word,
    required this.theme,
    required this.onTap,
    required this.onCustomise,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.push_pin,
        size: 16,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        word,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.tune, size: 18),
            tooltip: 'Customise',
            visualDensity: VisualDensity.compact,
            onPressed: onCustomise,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Unpin',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
