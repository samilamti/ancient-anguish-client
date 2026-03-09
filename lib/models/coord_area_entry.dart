/// A single entry mapping exact coordinates to an area name and optional audio file.
class CoordAreaEntry {
  final int x;
  final int y;
  final String areaName;
  final String? audioPath;

  const CoordAreaEntry({
    required this.x,
    required this.y,
    required this.areaName,
    this.audioPath,
  });

  /// Creates a map key from coordinates for O(1) lookup.
  static String coordKey(int x, int y) => '$x,$y';

  /// This entry's map key.
  String get key => coordKey(x, y);
}
