#!/usr/bin/env bash
# Run the app on the current platform's desktop
# Usage: bash scripts/run.sh [--release]
set -euo pipefail

case "$(uname -s)" in
  Darwin*)            PLATFORM=macos   ;;
  Linux*)             PLATFORM=linux   ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
  *) echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

if [[ "${1:-}" == "--release" ]]; then
  echo "=== Running $PLATFORM (release) ==="
  flutter run -d "$PLATFORM" --release
else
  echo "=== Running $PLATFORM (debug) ==="
  flutter run -d "$PLATFORM"
fi
