import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../protocol/ansi/styled_span.dart';
import '../../providers/connection_provider.dart'
    show connectionServiceProvider, terminalBufferProvider;
import '../../providers/settings_provider.dart';
import '../widgets/terminal/terminal_line.dart';

/// Full-screen scrollback view of the terminal buffer.
///
/// The live [TerminalView] is tail-only and doesn't scroll — this screen
/// exists for the occasional "look back at what just happened" need.
/// The buffer is snapshotted on open so new lines arriving in the
/// background don't shift the content under the user while they're
/// reading.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final List<StyledLine> _lines;
  late final double _fontSize;

  @override
  void initState() {
    super.initState();
    _lines = List.of(ref.read(terminalBufferProvider));
    _fontSize = ref.read(settingsProvider).fontSize;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: SafeArea(
        child: SelectionArea(
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
                onCommandTap: (cmd) {
                  if (cmd.trim().isEmpty) return;
                  ref.read(connectionServiceProvider).sendCommand(cmd);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
