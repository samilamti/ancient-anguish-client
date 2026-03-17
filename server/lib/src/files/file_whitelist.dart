/// Validates and sanitizes file names for the per-user file API.
///
/// Only whitelisted file names are allowed. This is the primary defense
/// against path traversal attacks.
class FileWhitelist {
  static const Set<String> _allowedNames = {
    'Immersions.md',
    'Aliases.md',
    'Area Configuration.md',
    'alts.json',
    'Command History.md',
    'settings.json',
  };

  static final _logFileRegex = RegExp(r'^logs/session_[a-zA-Z0-9_\-]+\.txt$');
  static final _chatHistoryRegex = RegExp(r'^Chat History/\d{4}-\d{2}-\d{2}\.md$');
  static final _tellHistoryRegex = RegExp(r'^Tell History/\d{4}-\d{2}-\d{2}\.md$');

  /// Returns the sanitized file name if allowed, or `null` if disallowed.
  ///
  /// Rejects path traversal attempts (`..`, backslash, absolute paths)
  /// and anything not in the whitelist.
  static String? validate(String name) {
    // Reject empty.
    if (name.isEmpty) return null;

    // Reject path traversal.
    if (name.contains('..')) return null;
    if (name.contains('\\')) return null;
    if (name.startsWith('/')) return null;

    // Reject null bytes.
    if (name.contains('\x00')) return null;

    // Check exact whitelist.
    if (_allowedNames.contains(name)) return name;

    // Check pattern-based allowances.
    if (_logFileRegex.hasMatch(name)) return name;
    if (_chatHistoryRegex.hasMatch(name)) return name;
    if (_tellHistoryRegex.hasMatch(name)) return name;

    return null;
  }
}
