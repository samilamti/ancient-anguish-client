#!/usr/bin/env bash
# Run the app on Windows desktop
# Usage: bash scripts/run.sh [--release]
set -euo pipefail

if [[ "${1:-}" == "--release" ]]; then
  echo "=== Running Windows (release) ==="
  flutter run -d windows --release
else
  echo "=== Running Windows (debug) ==="
  flutter run -d windows
fi
