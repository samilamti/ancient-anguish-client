import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/config/coord_area_config.dart';

/// Provides the [CoordAreaConfig] singleton.
///
/// Auto-loads from `Area Configuration.md` in the working directory on creation.
final coordAreaConfigProvider =
    NotifierProvider<CoordAreaConfigNotifier, CoordAreaConfig>(
        CoordAreaConfigNotifier.new);

class CoordAreaConfigNotifier extends Notifier<CoordAreaConfig> {
  @override
  CoordAreaConfig build() {
    final config = CoordAreaConfig();
    config.loadFromFileSync('Area Configuration.md');
    return config;
  }

  /// Reloads the configuration from the default file.
  Future<void> reload() async {
    await state.loadFromFile('Area Configuration.md');
    ref.notifyListeners();
  }
}
