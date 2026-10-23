import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../protocol/ansi/styled_span.dart';
import '../../providers/connection_provider.dart' show terminalBufferProvider;
import '../../providers/link_command_provider.dart';
import '../../providers/local_features_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/common/escape_dismiss.dart';
import '../widgets/terminal/terminal_line.dart';
import 'text_link_rules_screen.dart' show RuleListKind, openTextLinkRuleEditor;

/// Scrollback view of the terminal buffer — a right-docked drawer panel
/// on desktop, fullscreen on mobile.
///
/// The live [TerminalView] is tail-only and doesn't scroll — this screen
/// exists for the occasional "look back at what just happened" need.
/// The buffer is snapshotted on open so new lines arriving in the
/// background don't shift the content under the user while they're
/// reading.
///
/// Selecting text adds "Create Text Link Rule" (and, in local builds,
/// "Create Trigger") to the selection menu, opening the same editors the
/// live terminal's menu does, seeded from the selection.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final List<StyledLine> _lines;
  late final double _fontSize;
  late final double _extraSpacing;

  /// What the SelectionArea currently has selected, for the rule actions.
  String _selected = '';

  @override
  void initState() {
    super.initState();
    // Warm the marker probe so the menu reads a settled answer.
    ref.read(localFeaturesAvailableProvider);
    _lines = List.of(ref.read(terminalBufferProvider));
    final settings = ref.read(settingsProvider);
    _fontSize = settings.fontSize;
    _extraSpacing = settings.lineSpacing.extraFor(_fontSize);
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: SafeArea(
        child: SelectionArea(
          onSelectionChanged: (content) => _selected = content?.plainText ?? '',
          contextMenuBuilder: _buildContextMenu,
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: _lines.length,
            itemBuilder: (context, i) {
              final lineIndex = _lines.length - 1 - i;
              return TerminalLine(
                line: _lines[lineIndex],
                lineIndex: lineIndex,
                fontSize: _fontSize,
                extraSpacing: _extraSpacing,
                onCommandTap: (cmd) {
                  if (cmd.trim().isEmpty) return;
                  ref.read(linkCommandSenderProvider)(cmd);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ),
    );
    return EscapeDismiss(child: scaffold);
  }

  Widget _buildContextMenu(
    BuildContext menuContext,
    SelectableRegionState region,
  ) {
    final seed = _selected;
    final localFeatures =
        ref.read(localFeaturesAvailableProvider).value ?? false;
    void create(RuleListKind kind) {
      region.hideToolbar();
      openTextLinkRuleEditor(context, initialMatchText: seed, kind: kind);
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: region.contextMenuAnchors,
      buttonItems: [
        ...region.contextMenuButtonItems,
        if (seed.trim().isNotEmpty)
          ContextMenuButtonItem(
            label: 'Create Text Link Rule',
            onPressed: () => create(RuleListKind.textLink),
          ),
        if (seed.trim().isNotEmpty && localFeatures)
          ContextMenuButtonItem(
            label: 'Create Trigger',
            onPressed: () => create(RuleListKind.commandTrigger),
          ),
      ],
    );
  }
}
