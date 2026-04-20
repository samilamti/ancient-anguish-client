#!/usr/bin/env bash
# Run the Flutter app on macOS (debug, hot reload enabled).
# Usage:
#   bash scripts/run-macos.sh                                   # normal run
#   bash scripts/run-macos.sh --dart-define=AA_SUB_SEED=true    # seeded Support screen
set -euo pipefail
exec flutter run -d macos "$@"
