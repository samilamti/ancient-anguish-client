#!/usr/bin/env bash
# Build Windows release and package to releases/
# Usage: bash scripts/build-release.sh
set -euo pipefail

echo "=== Static Analysis ==="
flutter analyze --fatal-infos
echo ""

echo "=== Running Tests ==="
flutter test
echo ""

echo "=== Building Windows Release ==="
flutter build windows --release
echo ""

echo "=== Packaging Release ==="
RELEASE_DIR="build/windows/x64/runner/Release"
OUT="releases/ancient-anguish-client-windows-x64.zip"

if [ ! -d "$RELEASE_DIR" ]; then
  echo "ERROR: Build output not found at $RELEASE_DIR"
  exit 1
fi

mkdir -p releases
powershell -Command "Compress-Archive -Path '$RELEASE_DIR/*' -DestinationPath '$OUT' -Force"

SIZE=$(powershell -Command "(Get-Item '$OUT').Length / 1MB" | tr -d '\r')
echo ""
echo "=== Release packaged ==="
echo "Output: $OUT (${SIZE} MB)"
