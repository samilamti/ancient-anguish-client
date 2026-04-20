/// Controls whether the `HH:MM` timestamp column is rendered in front of
/// each social message.
enum TimestampMode {
  /// Always render the timestamp. Default.
  show,

  /// Reserve the timestamp column but only make it visible while the pointer
  /// is hovering the message row. Keeps message text from shifting.
  showOnHover,

  /// Omit the timestamp column entirely; messages use the reclaimed width.
  hide;

  /// Serialized name persisted in settings.json.
  String get storageKey => name;

  static TimestampMode fromStorageKey(String? key) {
    return TimestampMode.values.firstWhere(
      (m) => m.storageKey == key,
      orElse: () => TimestampMode.show,
    );
  }

  /// Next mode in the cycle: show → showOnHover → hide → show.
  TimestampMode get next => switch (this) {
        TimestampMode.show => TimestampMode.showOnHover,
        TimestampMode.showOnHover => TimestampMode.hide,
        TimestampMode.hide => TimestampMode.show,
      };
}
