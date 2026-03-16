/// Abstract file storage interface.
///
/// Desktop: reads/writes local files via `dart:io` + `path_provider`.
/// Web: reads/writes via HTTP to the server's per-profile storage API.
///
/// File names are logical identifiers (e.g. `'Immersions.md'`, `'alts.json'`).
/// Implementations resolve these to actual storage locations.
abstract class StorageService {
  /// Reads the entire contents of a config file.
  ///
  /// Returns an empty string if the file does not exist or is empty.
  Future<String> readFile(String name);

  /// Reads a file and splits it into lines.
  ///
  /// Returns an empty list if the file does not exist or is empty.
  Future<List<String>> readFileLines(String name);

  /// Writes the entire contents of a config file, replacing any existing data.
  Future<void> writeFile(String name, String contents);

  /// Appends text to a file (for history/logs).
  Future<void> appendToFile(String name, String text);

  /// Returns `true` if the file exists and is non-empty.
  Future<bool> fileExists(String name);

  /// Returns the byte length of a file, or 0 if it does not exist.
  Future<int> fileLength(String name);

  /// Ensures the file exists, creating it with [defaultContents] if missing.
  Future<void> ensureFile(String name, [String defaultContents = '']);

  /// Ensures the storage directory and all subdirectories exist.
  Future<void> ensureDirectories();
}
