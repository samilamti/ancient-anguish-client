import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/framed_text_block.dart';

/// Sentinel delimiters for a framed-text (parchment) block in the terminal
/// buffer. Distinct code points from the map sentinel so the renderer can
/// dispatch unambiguously to either widget.
const String kFramedBlockSentinelPrefix = '\uF0E3';
const String kFramedBlockSentinelSuffix = '\uF0E4';

/// Holds every captured [FramedTextBlock] keyed by the id embedded in its
/// sentinel line. Mirrors [mapBlocksProvider] for parity.
final framedTextBlocksProvider =
    NotifierProvider<FramedTextBlocksNotifier, Map<int, FramedTextBlock>>(
  FramedTextBlocksNotifier.new,
);

class FramedTextBlocksNotifier
    extends Notifier<Map<int, FramedTextBlock>> {
  int _nextId = 0;

  @override
  Map<int, FramedTextBlock> build() => const {};

  int put(FramedTextBlock block) {
    final id = _nextId++;
    state = {...state, id: block};
    return id;
  }

  void clear() {
    _nextId = 0;
    state = const {};
  }
}

String sentinelForFramedBlockId(int id) =>
    '$kFramedBlockSentinelPrefix$id$kFramedBlockSentinelSuffix';

int? tryParseFramedBlockId(String plainText) {
  if (!plainText.startsWith(kFramedBlockSentinelPrefix)) return null;
  final end = plainText.indexOf(kFramedBlockSentinelSuffix, 1);
  if (end <= 1) return null;
  return int.tryParse(plainText.substring(1, end));
}
