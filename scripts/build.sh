#!/usr/bin/env bash
# Build the Windows desktop app (debug or release)
# Usage: bash scripts/build.sh [--release]
set -euo pipefail

MODE="debug"
if [[ "${1:-}" == "--release" ]]; then
  MODE="release"
fi

echo "=== Building Windows ($MODE) ==="
flutter build windows --"$MODE"

if [[ "$MODE" == "release" ]]; then
  echo "Output: build/windows/x64/runner/Release/"
else
  echo "Output: build/windows/x64/runner/Debug/"
fi

echo "=== Build complete ==="
