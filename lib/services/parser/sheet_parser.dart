/// Recognises the fixed-width output of `skills`, `score` and a shop's `list`
/// and turns it into a [Sheet].
///
/// Structural, like [BattleTextClassifier] and [RoomLineClassifier]: no parser
/// here is told which command was typed. Output can arrive unsolicited, and a
/// client that assumes it knows what it sent mis-renders the moment a trigger,
/// an alias chain or another player's action produces the same text.
///
/// Each parser has two halves — a cheap opener test that says "this line
/// could begin a sheet", and a full parse over the accumulated block. The split
/// exists because the decision is deferred: a block is only a sheet once enough
/// of it has arrived to be sure, and until then its lines must survive as
/// ordinary text. See [SheetCapture].
library;

import '../../models/sheet.dart';

/// A parser for one sheet kind.
abstract class SheetParser {
  const SheetParser();

  /// Whether [plainText] could be the first line of this sheet.
  bool isOpening(String plainText);

  /// Whether [plainText] can appear inside the block (after the opener).
  /// Blank lines are handled by [SheetCapture], not here.
  bool isBody(String plainText);

  /// Builds the sheet from the accumulated block, or returns null when it
  /// turned out not to be one — in which case the lines are emitted verbatim.
  Sheet? parse(List<String> lines);

  /// Hard cap on how many lines to hold before giving up, so a mis-fire can
  /// never swallow an unbounded amount of output.
  int get maxLines => 40;
}

// ── skills ────────────────────────────────────────────────────────────────────

/// ```text
/// Your skills:
/// Axe                   14              Polearm                4
/// Club                  16              Rapier                18
/// ```
///
/// Two skills per line, each `Name<gap>Rating`. The name is matched lazily and
/// may contain spaces (`Curved Blade`, `Two Handed Sword`); a run of two or more
/// spaces is what separates a name from its number, and the number from the next
/// name. That is the whole grammar — no skill list is hard-coded, so AA can add
/// weapon classes without a client release.
class SkillsSheetParser extends SheetParser {
  const SkillsSheetParser();

  static final RegExp _header = RegExp(r'^\s*Your skills:\s*$');
  static final RegExp _entry = RegExp(r"([A-Za-z][A-Za-z'’\- ]*?)\s{2,}(\d+)\b");

  @override
  bool isOpening(String plainText) => _header.hasMatch(plainText);

  @override
  bool isBody(String plainText) => _entry.hasMatch(plainText);

  @override
  Sheet? parse(List<String> lines) {
    final skills = <SkillEntry>[];
    for (final line in lines.skip(1)) {
      for (final m in _entry.allMatches(line)) {
        final name = m.group(1)!.trim();
        final value = int.tryParse(m.group(2)!);
        if (name.isEmpty || value == null) continue;
        skills.add(SkillEntry(name, value));
      }
    }
    // One match is as likely to be a coincidence as a skill list.
    if (skills.length < 2) return null;
    return SkillsSheet(skills);
  }
}

// ── score ─────────────────────────────────────────────────────────────────────

/// ```text
/// Str: 16 (16)    Race : Dwarf (male)          Exp    : 647,031
/// ...
/// Hits : 178 (178)   Defend   : Dodge          You are: Sober
/// ```
///
/// **Fields are found by their labels, not by splitting on whitespace.** Two
/// things defeat splitting: a value can contain a double space
/// (`Age  : 5d  23h  39m  38s`), and a *label* can be padded away from its own
/// colon (`Exp    : 647,031`) — so no single gap width separates fields without
/// also cutting one in half. Instead every `Label :` position on the line is
/// located, and each value is the text running up to the next label.
///
/// The player's title line above the block is deliberately left as ordinary
/// output: it arrives before the first line this parser can recognise, and
/// reaching backwards to reclaim a line already emitted (possibly in an earlier
/// packet) would be far more fragile than simply letting it stand above.
class ScoreSheetParser extends SheetParser {
  const ScoreSheetParser();

  /// The stats line is unmistakable and always first in the block.
  static final RegExp _opening = RegExp(r'^\s*Str\s*:\s*\d+');

  /// A label is one capitalised word, optionally followed by a lower-case one
  /// (`Aiming at`, `Hunted by`, `You are`).
  static final RegExp _label = RegExp(r'([A-Z][A-Za-z]*(?:\s[a-z]+)?)\s*:');

  static const String _statusLabel = 'You are';

  @override
  bool isOpening(String plainText) => _opening.hasMatch(plainText);

  @override
  bool isBody(String plainText) => _label.hasMatch(plainText);

  @override
  int get maxLines => 16;

  @override
  Sheet? parse(List<String> lines) {
    final fields = <ScoreField>[];
    final statuses = <String>[];

    for (final line in lines) {
      final matches = _label.allMatches(line).toList();
      for (var i = 0; i < matches.length; i++) {
        final m = matches[i];
        final end = i + 1 < matches.length ? matches[i + 1].start : line.length;
        final label = m.group(1)!.trim();
        final value = line.substring(m.end, end).trim();
        if (value.isEmpty) continue;
        if (label == _statusLabel) {
          statuses.add(value);
        } else {
          fields.add(ScoreField(label, value));
        }
      }
    }

    // A `score` block always carries the stat block; anything with a couple of
    // stray colons is not one.
    if (fields.length < 4) return null;
    return ScoreSheet(fields: fields, statuses: statuses);
  }
}

// ── shop list ─────────────────────────────────────────────────────────────────

/// ```text
/// #_of_ _Item_________________________________________________________ _cost_
///    1  A green shield................................................   800
///    2  A small wooden shield.........................................   100
/// --More--(21/29)
/// ```
///
/// The header is optional — AA omits it on some shops — so a listing is also
/// recognised from its rows alone. A row is `count`, a name, a run of dots and a
/// price, which is specific enough that two of them in a row is not a
/// coincidence; a lone row without a header is left as text, because one dotted
/// line is a shape other output does produce.
class ShopListSheetParser extends SheetParser {
  const ShopListSheetParser();

  static final RegExp _header = RegExp(r'^#_of_\s+_Item_+\s+_cost_\s*$');
  static final RegExp _row = RegExp(r'^\s*(\d+)\s+(.+?)\.{3,}\s*(\d+)\s*$');
  static final RegExp _more = RegExp(r'^\s*--More--\((\d+)/(\d+)\)\s*$');

  @override
  bool isOpening(String plainText) =>
      _header.hasMatch(plainText) || _row.hasMatch(plainText);

  @override
  bool isBody(String plainText) =>
      _row.hasMatch(plainText) || _more.hasMatch(plainText);

  @override
  int get maxLines => 120;

  @override
  Sheet? parse(List<String> lines) {
    final items = <ShopItem>[];
    var hasHeader = false;
    int? shown;
    int? total;

    for (final line in lines) {
      if (_header.hasMatch(line)) {
        hasHeader = true;
        continue;
      }
      final more = _more.firstMatch(line);
      if (more != null) {
        shown = int.tryParse(more.group(1)!);
        total = int.tryParse(more.group(2)!);
        continue;
      }
      final row = _row.firstMatch(line);
      if (row == null) continue;
      final count = int.tryParse(row.group(1)!);
      final cost = int.tryParse(row.group(3)!);
      final name = row.group(2)!.trim();
      if (count == null || cost == null || name.isEmpty) continue;
      items.add(ShopItem(count: count, name: name, cost: cost));
    }

    if (items.isEmpty) return null;
    if (!hasHeader && items.length < 2) return null;
    return ShopListSheet(items, shown: shown, total: total);
  }
}

/// Every parser, in the order they are offered a line. Order only matters
/// between parsers whose openers could both match, which none currently do.
const List<SheetParser> kSheetParsers = [
  SkillsSheetParser(),
  ScoreSheetParser(),
  ShopListSheetParser(),
];

// ── capture ───────────────────────────────────────────────────────────────────

/// What the terminal buffer should do with the line it just offered.
enum SheetCaptureAction {
  /// Not part of a sheet — emit it as usual.
  passThrough,

  /// Held for a block still being accumulated — emit nothing.
  held,

  /// The block finished. Emit [SheetCaptureResult.sheet] as a sheet if it is
  /// non-null, then [SheetCaptureResult.releasedLines] verbatim, then
  /// [SheetCaptureResult.trailing] through the ordinary path.
  completed,
}

/// The outcome of offering one line to [SheetCapture].
///
/// The three payloads are emitted in field order and are never alternatives:
/// a *rejected* block returns every held line in [releasedLines] with a null
/// [sheet], and an *accepted* one returns the sheet plus any blank lines that
/// were held provisionally at its tail. Both cases can also carry a
/// [trailing] line. Nothing offered to the capture is ever dropped.
class SheetCaptureResult<T> {
  final SheetCaptureAction action;

  /// Non-null only when the block parsed as a sheet.
  final Sheet? sheet;

  /// Lines to emit verbatim, after [sheet] if there is one: the whole block
  /// when it was rejected, or the trailing blanks that turned out to sit after
  /// the sheet rather than inside it.
  final List<T> releasedLines;

  /// The line that ended the block. Not part of the sheet, so it still needs
  /// emitting. Null when the block was ended by a flush, by its line cap, or
  /// when the terminating line itself opened a new block and is now held.
  final T? trailing;

  const SheetCaptureResult(
    this.action, {
    this.sheet,
    this.releasedLines = const [],
    this.trailing,
  });
}

/// Accumulates the lines of a sheet and decides, at the end of the block,
/// whether to replace them with a widget.
///
/// Deferred decision is the same shape the map capture uses: the opening line of
/// a block is not proof, so lines are held until either the parser can confirm
/// them or something terminates the block — at which point held lines are either
/// replaced by one sheet or released untouched. Nothing is ever lost, which is
/// the property that matters: a mis-recognised block costs the player a widget,
/// never their output.
///
/// [T] is whatever the caller wants to hold alongside the plain text (in the
/// client, the fully-transformed `StyledLine`), so the capture never has to know
/// how a line is rendered.
class SheetCapture<T> {
  final List<SheetParser> parsers;

  SheetParser? _active;
  final List<String> _plain = [];
  final List<T> _held = [];

  /// Trailing blank lines are held provisionally: a blank can sit *inside* a
  /// score block (between the stat rows and the vitals rows), so a blank cannot
  /// terminate one on its own — but a run of them means the output moved on.
  int _pendingBlanks = 0;

  static const int _maxTrailingBlanks = 2;

  SheetCapture({this.parsers = kSheetParsers});

  bool get isCapturing => _active != null;

  /// Offers one line. [plainText] drives recognition; [line] is what gets held
  /// and released.
  SheetCaptureResult<T> offer(String plainText, T line) {
    if (_active == null) {
      return _tryOpen(plainText, line)
          ? SheetCaptureResult<T>(SheetCaptureAction.held)
          : SheetCaptureResult<T>(SheetCaptureAction.passThrough);
    }

    if (plainText.trim().isEmpty) {
      _pendingBlanks++;
      if (_pendingBlanks > _maxTrailingBlanks) {
        return _finish(trailingPlain: plainText, trailing: line);
      }
      _hold(plainText, line);
      return SheetCaptureResult<T>(SheetCaptureAction.held);
    }

    if (_active!.isBody(plainText)) {
      _pendingBlanks = 0;
      _hold(plainText, line);
      // At the cap, close the block but keep the line — it is already held.
      if (_plain.length >= _active!.maxLines) return _finish();
      return SheetCaptureResult<T>(SheetCaptureAction.held);
    }

    // Something else entirely — the block ended on the line before this one.
    return _finish(trailingPlain: plainText, trailing: line);
  }

  /// Abandons any block in progress and returns its lines unparsed.
  ///
  /// For when the player switches sheets *off* mid-block: they asked for raw
  /// text, so the lines already held have to appear as text. [flush] would
  /// parse them into the sheet they were about to become, which is the opposite
  /// of what was just requested.
  List<T> release() {
    final held = List<T>.from(_held);
    _active = null;
    _plain.clear();
    _held.clear();
    _pendingBlanks = 0;
    return held;
  }

  /// Ends any block in progress. Call when output is known to be complete (a
  /// prompt arrived) so a block that nothing terminated still reaches the
  /// player rather than sitting in the buffer forever.
  SheetCaptureResult<T> flush() {
    if (_active == null) {
      return SheetCaptureResult<T>(SheetCaptureAction.passThrough);
    }
    return _finish();
  }

  void _hold(String plainText, T line) {
    _plain.add(plainText);
    _held.add(line);
  }

  bool _tryOpen(String plainText, T line) {
    for (final parser in parsers) {
      if (parser.isOpening(plainText)) {
        _active = parser;
        _hold(plainText, line);
        return true;
      }
    }
    return false;
  }

  SheetCaptureResult<T> _finish({String? trailingPlain, T? trailing}) {
    final parser = _active!;

    // Trailing blanks were held on the chance the block continued; now that it
    // has ended they belong to the output *after* it, so they are released
    // rather than folded into the sheet or dropped.
    final trailingBlanks = <T>[];
    while (_plain.isNotEmpty && _plain.last.trim().isEmpty) {
      _plain.removeLast();
      trailingBlanks.insert(0, _held.removeLast());
    }

    final sheet = _plain.isEmpty ? null : parser.parse(_plain);
    final released = <T>[
      if (sheet == null) ..._held,
      ...trailingBlanks,
    ];

    _active = null;
    _plain.clear();
    _held.clear();
    _pendingBlanks = 0;

    // The line that ended one block can begin the next — two `list` pages, or a
    // score straight after a skills sheet. Re-offering it here is what keeps
    // back-to-back sheets from costing every other one its opening line.
    var stillTrailing = trailing;
    if (trailingPlain != null &&
        trailing != null &&
        _tryOpen(trailingPlain, trailing)) {
      stillTrailing = null;
    }

    return SheetCaptureResult<T>(
      SheetCaptureAction.completed,
      sheet: sheet,
      releasedLines: released,
      trailing: stillTrailing,
    );
  }
}
