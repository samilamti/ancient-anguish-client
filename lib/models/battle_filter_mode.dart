/// How the terminal treats Ancient Anguish's combat spam.
///
/// A fight emits several hit/miss/vitals lines per second, so a few minutes of
/// combat can push everything else out of a 5000-line scrollback. All three
/// modes show the player every line — they differ only in *where*, and in what
/// survives in the buffer afterwards.
enum BattleFilterMode {
  /// No filtering: every combat line is appended like any other output.
  /// Default, because it is what every other MUD client does.
  off,

  /// Combat lines share a single slot at the tail of the buffer: each new one
  /// overwrites the last. The player reads each line as it lands, but a
  /// thousand-round fight leaves one line of scrollback instead of a thousand.
  collapse,

  /// Combat lines are kept out of the buffer entirely and shown in the
  /// floating battle HUD instead, alongside running hit/miss tallies.
  hud;

  /// Serialized name persisted in settings.json.
  String get storageKey => name;

  static BattleFilterMode fromStorageKey(String? key) {
    return BattleFilterMode.values.firstWhere(
      (m) => m.storageKey == key,
      orElse: () => BattleFilterMode.off,
    );
  }

  /// Label for the settings UI.
  String get label => switch (this) {
        BattleFilterMode.off => 'Show every line',
        BattleFilterMode.collapse => 'Collapse in place',
        BattleFilterMode.hud => 'Battle HUD only',
      };

  /// One-line explanation for the settings UI.
  String get description => switch (this) {
        BattleFilterMode.off => 'Combat fills the scrollback as usual',
        BattleFilterMode.collapse =>
          'Each combat line replaces the previous one',
        BattleFilterMode.hud =>
          'Combat moves to a floating panel with hit tallies',
      };

  /// Whether combat lines are kept out of the terminal buffer under this mode.
  bool get filtersTerminal => this != BattleFilterMode.off;
}
