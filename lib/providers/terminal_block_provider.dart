import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/terminal_block.dart';
import '../protocol/ansi/styled_span.dart';
import 'connection_provider.dart' show terminalBufferProvider;
import 'settings_provider.dart';

/// A recorded block boundary in the terminal buffer.
class BlockBoundary {
  final int lineIndex;
  final BlockBoundaryReason reason;

  const BlockBoundary({required this.lineIndex, required this.reason});
}

/// Tracks block boundary events emitted by the output loop and input bar.
final blockBoundaryProvider =
    NotifierProvider<BlockBoundaryNotifier, List<BlockBoundary>>(
        BlockBoundaryNotifier.new);

class BlockBoundaryNotifier extends Notifier<List<BlockBoundary>> {
  Timer? _timeoutTimer;
  int _lastKnownBufferLength = 0;

  @override
  List<BlockBoundary> build() {
    final enabled = ref.watch(settingsProvider).blockModeEnabled;
    if (!enabled) return [];

    // Listen for buffer changes to manage timeout-based boundaries.
    ref.listen<List<StyledLine>>(terminalBufferProvider, (previous, next) {
      _onBufferChanged(previous?.length ?? 0, next.length);
    });

    ref.onDispose(() {
      _timeoutTimer?.cancel();
    });

    return [];
  }

  void _onBufferChanged(int previousLength, int currentLength) {
    if (currentLength <= previousLength) return;
    _lastKnownBufferLength = currentLength;

    // Reset the timeout timer — new data arrived.
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 1), () {
      // No new data for 1 second — insert a timeout boundary.
      markTimeoutBoundary(_lastKnownBufferLength);
    });
  }

  /// Called from connection_provider when a prompt is detected.
  void markPromptBoundary(int lineIndex) {
    _addBoundary(lineIndex, BlockBoundaryReason.prompt);
  }

  /// Called from InputBar when the user sends a command.
  void markCommandBoundary(int lineIndex) {
    _addBoundary(lineIndex, BlockBoundaryReason.userCommand);
  }

  /// Called internally when no output arrives for >1 second.
  void markTimeoutBoundary(int lineIndex) {
    _addBoundary(lineIndex, BlockBoundaryReason.timeout);
  }

  /// Adjusts all boundary indices after the flat buffer trims old lines.
  void adjustForTrim(int removedCount) {
    if (removedCount <= 0) return;
    final adjusted = <BlockBoundary>[];
    for (final b in state) {
      final newIndex = b.lineIndex - removedCount;
      if (newIndex >= 0) {
        adjusted.add(BlockBoundary(lineIndex: newIndex, reason: b.reason));
      }
    }
    state = adjusted;
  }

  /// Called on disconnect to clear all boundaries.
  void reset() {
    _timeoutTimer?.cancel();
    _lastKnownBufferLength = 0;
    state = [];
  }

  void _addBoundary(int lineIndex, BlockBoundaryReason reason) {
    // Avoid duplicate boundaries at the same index.
    if (state.isNotEmpty && state.last.lineIndex == lineIndex) return;
    state = [...state, BlockBoundary(lineIndex: lineIndex, reason: reason)];
  }
}

/// Derived provider that slices the flat terminal buffer into blocks
/// using the recorded boundaries.
final terminalBlocksProvider = Provider<List<TerminalBlock>>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.blockModeEnabled) return [];

  final lines = ref.watch(terminalBufferProvider);
  final boundaries = ref.watch(blockBoundaryProvider);

  return _buildBlocks(lines, boundaries);
});

List<TerminalBlock> _buildBlocks(
    List<StyledLine> lines, List<BlockBoundary> boundaries) {
  if (lines.isEmpty) return [];

  final blocks = <TerminalBlock>[];
  var startIndex = 0;

  for (final boundary in boundaries) {
    // Clamp boundary to valid range.
    final endIndex = boundary.lineIndex.clamp(0, lines.length);
    if (endIndex > startIndex) {
      blocks.add(TerminalBlock(
        id: startIndex,
        startLineIndex: startIndex,
        lines: lines.sublist(startIndex, endIndex),
        reason: boundary.reason,
      ));
    }
    startIndex = endIndex;
  }

  // Remaining lines after the last boundary form the current (open) block.
  if (startIndex < lines.length) {
    blocks.add(TerminalBlock(
      id: startIndex,
      startLineIndex: startIndex,
      lines: lines.sublist(startIndex),
      reason: BlockBoundaryReason.initial,
    ));
  }

  return blocks;
}
