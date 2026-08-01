/// Structured renderings of MUD command output — "sheets".
///
/// A sheet is the same idea as the map block: recognise a command's output by
/// its shape, capture it into a typed model, and let a widget render it in the
/// terminal instead of the raw fixed-width text. The text is column-aligned for
/// an 80-column terminal, which is exactly what stops being readable on a phone
/// and stops being useful when you only wanted two of the twenty numbers.
///
/// Every sheet is recognised structurally, never by echoing the command the
/// player typed: output can arrive unsolicited (a `score` triggered by a script,
/// somebody else's `list` scrolling past) and the client never assumes it knows
/// what was sent.
sealed class Sheet {
  const Sheet();
}

/// One weapon skill and its rating, from `skills`.
class SkillEntry {
  final String name;
  final int value;

  const SkillEntry(this.name, this.value);

  @override
  bool operator ==(Object other) =>
      other is SkillEntry && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);

  @override
  String toString() => 'SkillEntry($name, $value)';
}

/// `skills` — the player's weapon proficiencies.
class SkillsSheet extends Sheet {
  final List<SkillEntry> skills;

  const SkillsSheet(this.skills);

  /// The highest rating on the sheet, used to scale the bars. Never zero, so
  /// callers can divide by it without guarding.
  int get maxValue =>
      skills.fold(1, (best, s) => s.value > best ? s.value : best);
}

/// One `Label : value` pair from `score`.
class ScoreField {
  final String label;
  final String value;

  const ScoreField(this.label, this.value);

  @override
  bool operator ==(Object other) =>
      other is ScoreField && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);

  @override
  String toString() => 'ScoreField($label: $value)';
}

/// `score` — the player's stats, split into the handful of fields that change
/// while you play and the rest, which you look up once an hour.
class ScoreSheet extends Sheet {
  /// Every field except the `You are:` lines, in the order the MUD printed
  /// them (reading order: down column one, then column two, then three).
  final List<ScoreField> fields;

  /// The `You are:` values — Sober, Thirsty, Hungry, Very encumbered …
  final List<String> statuses;

  /// Change in `Exp` / `Money` since the previous score sheet of the session,
  /// or null when this is the first one (or the field was unreadable).
  ///
  /// Filled in by `SheetsNotifier.put`, not by the parser: a delta is a fact
  /// about the *sequence* of sheets, and the parser only ever sees one block.
  final int? expDelta;
  final int? moneyDelta;

  const ScoreSheet({
    required this.fields,
    required this.statuses,
    this.expDelta,
    this.moneyDelta,
  });

  /// Labels worth showing while collapsed, per the fields that actually move
  /// during play. Statuses are always shown — they change the most of all.
  static const Set<String> frequentLabels = {
    'Exp',
    'Money',
    'Wimpy',
    'Hunted by',
  };

  /// Labels whose value is tracked across sheets so a delta can be shown.
  static const String expLabel = 'Exp';
  static const String moneyLabel = 'Money';

  /// Collapsed view: the movers only.
  List<ScoreField> get frequentFields =>
      fields.where((f) => frequentLabels.contains(f.label)).toList();

  /// Expanded view: everything else, so the two lists together are [fields]
  /// with no duplicates and nothing dropped.
  List<ScoreField> get restFields =>
      fields.where((f) => !frequentLabels.contains(f.label)).toList();

  int? get expValue => numericValueOf(expLabel);
  int? get moneyValue => numericValueOf(moneyLabel);

  /// The leading number of the field labelled [label], with AA's thousands
  /// commas removed and any trailing unit ignored (`7,118 coins` → 7118).
  /// Null when the field is absent or carries no number (`Wounds : none`).
  int? numericValueOf(String label) {
    for (final field in fields) {
      if (field.label != label) continue;
      final m = RegExp(r'-?[\d,]*\d').firstMatch(field.value);
      if (m == null) return null;
      return int.tryParse(m.group(0)!.replaceAll(',', ''));
    }
    return null;
  }

  /// The delta shown next to [label], or null when there is none to show.
  int? deltaFor(String label) => switch (label) {
        expLabel => expDelta,
        moneyLabel => moneyDelta,
        _ => null,
      };

  ScoreSheet withDeltas({int? expDelta, int? moneyDelta}) => ScoreSheet(
        fields: fields,
        statuses: statuses,
        expDelta: expDelta,
        moneyDelta: moneyDelta,
      );
}

/// One row of a shop's `list` output.
class ShopItem {
  final int count;
  final String name;
  final int cost;

  const ShopItem({
    required this.count,
    required this.name,
    required this.cost,
  });

  /// The command that buys this item: the shop's own wording minus the
  /// leading article, which AA prints for display and does not accept as part
  /// of an object name (`An antique staff` → `buy antique staff`).
  String get buyCommand => 'buy $buyTarget';

  /// The item name as an object reference — see [buyCommand].
  String get buyTarget => name
      .replaceFirst(RegExp(r'^(?:an|a|the|some)\s+', caseSensitive: false), '')
      .trim();

  @override
  bool operator ==(Object other) =>
      other is ShopItem &&
      other.count == count &&
      other.name == name &&
      other.cost == cost;

  @override
  int get hashCode => Object.hash(count, name, cost);

  @override
  String toString() => 'ShopItem($count x $name @ $cost)';
}

/// A shop inventory listing (`list swords`, `list packs`, …).
class ShopListSheet extends Sheet {
  final List<ShopItem> items;

  /// From a trailing `--More--(21/29)`: how many rows this page showed and how
  /// many exist. Null when the listing was complete.
  final int? shown;
  final int? total;

  const ShopListSheet(this.items, {this.shown, this.total});

  bool get isTruncated => shown != null && total != null && shown! < total!;

  /// Cheapest item first is the useful order when you are shopping, but the
  /// MUD's alphabetical order is what the player asked for — so this is
  /// offered, not imposed. The widget lets them switch.
  List<ShopItem> get byCost =>
      [...items]..sort((a, b) => a.cost.compareTo(b.cost));
}
