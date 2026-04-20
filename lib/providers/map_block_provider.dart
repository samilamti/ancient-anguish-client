import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/map_block.dart';

/// Prefix stored in the terminal buffer as a stand-in line for a captured
/// map block. Two private-use characters book-end the numeric block id.
/// Using private-use code points keeps the sentinel impossible to collide
/// with anything the MUD would legitimately send.
const String kMapBlockSentinelPrefix = '\uF0E1';
const String kMapBlockSentinelSuffix = '\uF0E2';

/// Holds every captured [MapBlock] in memory, keyed by the id that appears
/// inside its terminal-buffer sentinel line. When the terminal clears, the
/// notifier is also cleared.
final mapBlocksProvider =
    NotifierProvider<MapBlocksNotifier, Map<int, MapBlock>>(
  MapBlocksNotifier.new,
);

class MapBlocksNotifier extends Notifier<Map<int, MapBlock>> {
  int _nextId = 0;

  @override
  Map<int, MapBlock> build() => const {};

  /// Registers a block and returns the id to embed in the sentinel line.
  int put(MapBlock block) {
    final id = _nextId++;
    state = {...state, id: block};
    return id;
  }

  void clear() {
    _nextId = 0;
    state = const {};
  }
}

/// Builds a sentinel StyledLine text for the given block [id]. Keep this in
/// a helper so the accumulator and the renderer never drift.
String sentinelForBlockId(int id) =>
    '$kMapBlockSentinelPrefix$id$kMapBlockSentinelSuffix';

/// Parses a block id out of a sentinel line text, or returns `null` if the
/// text doesn't carry a sentinel.
int? tryParseBlockId(String plainText) {
  if (!plainText.startsWith(kMapBlockSentinelPrefix)) return null;
  final end = plainText.indexOf(kMapBlockSentinelSuffix, 1);
  if (end <= 1) return null;
  return int.tryParse(plainText.substring(1, end));
}
