import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Marker asset that switches on the local-only features: command triggers
/// and `#N command` repeats. The file is gitignored, so a checkout (and
/// therefore every CI build) never has it: the features exist only on a
/// machine where someone has created it by hand. Its contents are ignored. The
/// release scripts refuse to build while it exists, so a local store build
/// can't carry it either (scripts/check-no-local-features.sh).
const localFeaturesMarkerAsset = 'assets/local/command_triggers.enabled';

/// Whether this build carries [localFeaturesMarkerAsset].
final localFeaturesAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    await rootBundle.load(localFeaturesMarkerAsset);
    return true;
  } catch (_) {
    return false;
  }
});
