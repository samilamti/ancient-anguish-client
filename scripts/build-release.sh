#!/usr/bin/env bash
# Build release and package to releases/
# Usage: bash scripts/build-release.sh
set -euo pipefail

case "$(uname -s)" in
  Darwin*)            PLATFORM=macos   ;;
  Linux*)             PLATFORM=linux   ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
  *) echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

echo "=== Static Analysis ==="
flutter analyze --fatal-infos
echo ""

echo "=== Running Tests ==="
flutter test
echo ""

echo "=== Building $PLATFORM Release ==="
flutter build "$PLATFORM" --release
echo ""

echo "=== Packaging Release ==="
mkdir -p releases

case "$PLATFORM" in
  macos)
    RELEASE_DIR="build/macos/Build/Products/Release"
    OUT="releases/ancient-anguish-client-macos.zip"
    if [ ! -d "$RELEASE_DIR/ancient_anguish_client.app" ]; then
      echo "ERROR: Build output not found at $RELEASE_DIR/ancient_anguish_client.app"
      exit 1
    fi
    (cd "$RELEASE_DIR" && zip -r -y - ancient_anguish_client.app) > "$OUT"
    SIZE=$(du -m "$OUT" | cut -f1)
    ;;
  windows)
    RELEASE_DIR="build/windows/x64/runner/Release"
    OUT="releases/ancient-anguish-client-windows-x64.zip"
    if [ ! -d "$RELEASE_DIR" ]; then
      echo "ERROR: Build output not found at $RELEASE_DIR"
      exit 1
    fi
    powershell -Command "Compress-Archive -Path '$RELEASE_DIR/*' -DestinationPath '$OUT' -Force"
    SIZE=$(powershell -Command "(Get-Item '$OUT').Length / 1MB" | tr -d '\r')
    ;;
  linux)
    RELEASE_DIR="build/linux/x64/release/bundle"
    OUT="releases/ancient-anguish-client-linux-x64.tar.gz"
    if [ ! -d "$RELEASE_DIR" ]; then
      echo "ERROR: Build output not found at $RELEASE_DIR"
      exit 1
    fi
    tar -czf "$OUT" -C "$RELEASE_DIR" .
    SIZE=$(du -m "$OUT" | cut -f1)
    ;;
esac

echo ""
echo "=== Release packaged ==="
echo "Output: $OUT (${SIZE} MB)"
