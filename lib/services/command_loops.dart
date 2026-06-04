/// Recognises MUD "loop" commands and the command that interrupts them.
///
/// Currently `dotimes` → `breakdo`. When the user sends a loop command, the
/// input bar drops the break command into command history (recallable via the
/// Up-arrow / history sheet) so the user can quickly fire it to stop the loop.
/// The break command is never sent automatically — it is only added to history.
///
/// Add more pairs in [breakCommandFor].
class CommandLoops {
  const CommandLoops._();

  /// The break command to add to history after [command] is sent, or `null`
  /// if [command] is not a recognised loop command.
  ///
  /// Matches the verb only (`dotimes` on its own or `dotimes …`),
  /// case-insensitively, so `dotimesfoo` does not match.
  static String? breakCommandFor(String command) {
    final c = command.trim().toLowerCase();
    if (c == 'dotimes' || c.startsWith('dotimes ')) return 'breakdo';
    return null;
  }
}
