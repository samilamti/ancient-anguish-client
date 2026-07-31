import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sheet.dart';

/// Sentinel delimiters for a [Sheet] in the terminal buffer. Distinct private-use
/// code points from the map and parchment sentinels so the renderer can dispatch
/// unambiguously between all three.
const String kSheetSentinelPrefix = '\uF0E5';
const String kSheetSentinelSuffix = '\uF0E6';

/// Holds every captured [Sheet] keyed by the id embedded in its sentinel line.
/// Mirrors `mapBlocksProvider` and `framedTextBlocksProvider`.
final sheetsProvider = NotifierProvider<SheetsNotifier, Map<int, Sheet>>(
  SheetsNotifier.new,
);

class SheetsNotifier extends Notifier<Map<int, Sheet>> {
  int _nextId = 0;

  @override
  Map<int, Sheet> build() => const {};

  /// Registers a sheet and returns the id to embed in the sentinel line.
  int put(Sheet sheet) {
    final id = _nextId++;
    state = {...state, id: sheet};
    return id;
  }

  void clear() {
    _nextId = 0;
    state = const {};
  }
}

/// Per-sheet view state, keyed by sheet id.
///
/// Lives outside the widget because `TerminalLine` is stateless and rebuilt on
/// every buffer change — a flag held in widget state would reset itself the
/// moment the next line of output arrived. Keyed by id so two sheets in the
/// scrollback behave independently.
class SheetIdFlags extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  bool has(int id) => state.contains(id);

  void toggle(int id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void clear() => state = const {};
}

/// Which score sheets the player has expanded to the full stat block.
final expandedSheetsProvider =
    NotifierProvider<SheetIdFlags, Set<int>>(SheetIdFlags.new);

/// Which shop listings the player has re-sorted cheapest-first. The MUD's
/// alphabetical order is what they asked for, so the reorder is offered rather
/// than imposed.
final costSortedSheetsProvider =
    NotifierProvider<SheetIdFlags, Set<int>>(SheetIdFlags.new);

String sentinelForSheetId(int id) =>
    '$kSheetSentinelPrefix$id$kSheetSentinelSuffix';

int? tryParseSheetId(String plainText) {
  if (!plainText.startsWith(kSheetSentinelPrefix)) return null;
  final end = plainText.indexOf(kSheetSentinelSuffix, 1);
  if (end <= 1) return null;
  return int.tryParse(plainText.substring(1, end));
}
