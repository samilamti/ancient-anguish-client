/// Manages area-to-image file path mappings for terminal background images.
class AreaBackgroundManager {
  final Map<String, String> _userImageMap = {};

  /// Sets a user-configured image file path for an area.
  void setImageForArea(String areaName, String filePath) {
    _userImageMap[areaName] = filePath;
  }

  /// Removes a user-configured image mapping for an area.
  void removeImageForArea(String areaName) {
    _userImageMap.remove(areaName);
  }

  /// Returns all user-configured image mappings.
  Map<String, String> get userImageMap => Map.unmodifiable(_userImageMap);

  /// Loads user image mappings from a map (e.g., from settings storage).
  void loadUserImageMap(Map<String, String> map) {
    _userImageMap.clear();
    _userImageMap.addAll(map);
  }

  /// Returns the image file path for an area, or null if not mapped.
  String? getImageForArea(String areaName) {
    return _userImageMap[areaName];
  }
}
