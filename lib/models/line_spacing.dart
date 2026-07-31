/// Extra vertical space between terminal lines, as a fraction of the font size.
///
/// An accessibility/readability option layered on top of the font-size slider:
/// bumping the font makes glyphs bigger, this makes the *gaps* bigger, which is
/// what helps a reader who loses their place in dense MUD output. Off by
/// default so the terminal keeps its traditional density.
enum LineSpacing {
  none(0),
  quarter(25),
  third(33),
  half(50),
  threeQuarters(75),
  full(100);

  /// Extra leading as a percentage of the font size.
  final int percent;

  const LineSpacing(this.percent);

  /// Serialized value persisted in settings.json. Stored as the percentage
  /// rather than the enum name so a future intermediate step (say 40%) reads
  /// back sensibly instead of falling out to [none].
  String get storageKey => percent.toString();

  static LineSpacing fromStorageKey(String? key) {
    final parsed = key == null ? null : int.tryParse(key);
    if (parsed == null) return LineSpacing.none;
    // Nearest defined step, so an unknown percentage degrades to the closest
    // thing the UI can actually display.
    return LineSpacing.values.reduce((a, b) =>
        (a.percent - parsed).abs() <= (b.percent - parsed).abs() ? a : b);
  }

  /// Pixels of extra leading for [fontSize].
  double extraFor(double fontSize) => fontSize * percent / 100;

  /// Label for the settings UI.
  String get label => this == LineSpacing.none ? 'Off' : '$percent%';
}
