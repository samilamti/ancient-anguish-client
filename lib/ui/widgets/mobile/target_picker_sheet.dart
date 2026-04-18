import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/recent_words_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = ref.watch(recentWordsProvider);
    final matches = completionsFor(words, _prefix).take(_maxResults).toList();
    final viewInsets = MediaQuery.of(context).viewInsets;

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
                      '${matches.length} match${matches.length == 1 ? '' : 'es'}',
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
                child: TextField(
                  controller: _filterController,
                  autofocus: false,
                  decoration: const InputDecoration(
                    hintText: 'Filter…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  style: const TextStyle(fontFamily: 'JetBrainsMono'),
                  onChanged: (value) => setState(() => _prefix = value.trim()),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: matches.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _prefix.isEmpty
                                ? 'No recent words yet.'
                                : 'No matches for "$_prefix".',
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final word = matches[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              word,
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(word),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
