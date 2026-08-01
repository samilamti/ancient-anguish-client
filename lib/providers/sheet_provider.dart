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

  /// Exp and Money as of the last `score`, so the next one can show what
  /// changed. Held here rather than in the parser because a delta is a fact
  /// about the sequence of sheets, and a parser only ever sees one block.
  int? _lastExp;
  int? _lastMoney;

  @override
  Map<int, Sheet> build() => const {};

  /// Registers a sheet and returns the id to embed in the sentinel line.
  int put(Sheet sheet) {
    final resolved = sheet is ScoreSheet ? _withScoreDeltas(sheet) : sheet;
    final id = _nextId++;
    state = {...state, id: resolved};
    return id;
  }

  /// Fills in [ScoreSheet.expDelta] / [ScoreSheet.moneyDelta] against the
  /// previous sheet and remembers this one's values for the next.
  ///
  /// A field that didn't parse leaves both the delta and the remembered value
  /// alone, so one unreadable `score` doesn't turn the following sheet's delta
  /// into a jump measured from nothing.
  ScoreSheet _withScoreDeltas(ScoreSheet sheet) {
    final exp = sheet.expValue;
    final money = sheet.moneyValue;
    final withDeltas = sheet.withDeltas(
      expDelta: (exp != null && _lastExp != null) ? exp - _lastExp! : null,
      moneyDelta:
          (money != null && _lastMoney != null) ? money - _lastMoney! : null,
    );
    if (exp != null) _lastExp = exp;
    if (money != null) _lastMoney = money;
    return withDeltas;
  }

  void clear() {
    _nextId = 0;
    // Clearing the buffer throws away the sheets a delta would be measured
    // from, and it is also what a disconnect does — so the next score starts a
    // fresh baseline rather than reporting a jump across two sessions.
    _lastExp = null;
    _lastMoney = null;
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
