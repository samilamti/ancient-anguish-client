#!/usr/bin/env bash
# Build the desktop app (debug or release)
# Usage: bash scripts/build.sh [--release]
set -euo pipefail

MODE="debug"
if [[ "${1:-}" == "--release" ]]; then
  MODE="release"
fi

case "$(uname -s)" in
  Darwin*)            PLATFORM=macos   ;;
  Linux*)             PLATFORM=linux   ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
  *) echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

echo "=== Building $PLATFORM ($MODE) ==="
flutter build "$PLATFORM" --"$MODE"

if [[ "$MODE" == "release" ]]; then
  case "$PLATFORM" in
    macos)   echo "Output: build/macos/Build/Products/Release/" ;;
    windows) echo "Output: build/windows/x64/runner/Release/" ;;
    linux)   echo "Output: build/linux/x64/release/bundle/" ;;
  esac
else
  case "$PLATFORM" in
    macos)   echo "Output: build/macos/Build/Products/Debug/" ;;
    windows) echo "Output: build/windows/x64/runner/Debug/" ;;
    linux)   echo "Output: build/linux/x64/debug/bundle/" ;;
  esac
fi

echo "=== Build complete ==="
