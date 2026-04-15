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
    # Codesign with Developer ID if a signing identity is available
    SIGN_IDENTITY=""
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
      SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
      echo ""
      echo "=== Codesigning with: $SIGN_IDENTITY ==="
      codesign --deep --force --options runtime \
        --sign "$SIGN_IDENTITY" \
        --entitlements macos/Runner/Release.entitlements \
        "$RELEASE_DIR/ancient_anguish_client.app"
      codesign --verify --deep --strict "$RELEASE_DIR/ancient_anguish_client.app"
      echo "App signed and verified"
    else
      echo "Tip: Install a Developer ID Application certificate to sign the app"
    fi
    (cd "$RELEASE_DIR" && zip -r -y - ancient_anguish_client.app) > "$OUT"
    SIZE=$(du -m "$OUT" | cut -f1)
    # Build styled DMG if create-dmg is available
    if command -v create-dmg &>/dev/null; then
      echo ""
      echo "=== Building DMG ==="
      chmod +x installers/macos/build-dmg.sh
      DMG_ARGS=("local")
      if [ -n "$SIGN_IDENTITY" ]; then
        DMG_ARGS+=(--codesign-identity "$SIGN_IDENTITY")
      fi
      ./installers/macos/build-dmg.sh "${DMG_ARGS[@]}"
      mv ancient-anguish-client-macos-local.dmg releases/ancient-anguish-client-macos.dmg
      echo "DMG: releases/ancient-anguish-client-macos.dmg"
    else
      echo "Tip: brew install create-dmg to also build a styled DMG"
    fi
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
