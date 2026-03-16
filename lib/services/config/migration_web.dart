import '../../models/area_config_entry.dart';

/// No-op on web — CWD-based legacy config files don't exist.
Map<String, AreaConfigEntry> loadLegacyCwdConfig() => {};
