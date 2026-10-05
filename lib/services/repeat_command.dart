/// Parser for the local-only repeat command `#<count> <command>`.
///
/// `#15 buy beer;drink beer` sends `buy beer` and `drink beer` fifteen times
/// over, in that order. The body is alias-expanded once by the caller (which
/// also splits it on `;`) and the result repeated, so the body may use aliases
/// exactly as a typed command would.
///
/// Only honoured when the local-features marker is bundled; otherwise the
/// caller sends the line to the MUD untouched.
class RepeatCommand {
  final int count;
  final String body;

  const RepeatCommand(this.count, this.body);

  static final RegExp _pattern = RegExp(r'^#(\d+)\s+(\S.*)$', dotAll: true);

  /// Returns `null` when [input] is not a repeat command, including a count of
  /// zero, which repeats nothing.
  static RepeatCommand? parse(String input) {
    final match = _pattern.firstMatch(input.trim());
    if (match == null) return null;
    final count = int.tryParse(match.group(1)!);
    if (count == null || count < 1) return null;
    return RepeatCommand(count, match.group(2)!.trim());
  }

  /// [expandedBody] repeated [count] times.
  List<String> repeat(List<String> expandedBody) => [
        for (var i = 0; i < count; i++) ...expandedBody,
      ];
}
