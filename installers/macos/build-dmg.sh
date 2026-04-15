#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: build-dmg.sh <version> [--codesign-identity <identity>]}"
# Strip leading 'v' from version tag
VERSION="${VERSION#v}"
shift

# Parse optional codesign identity
CODESIGN_IDENTITY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --codesign-identity)
      CODESIGN_IDENTITY="${2:?--codesign-identity requires a value}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

APP_NAME="ancient_anguish_client.app"
DMG_NAME="ancient-anguish-client-macos-${VERSION}.dmg"
RELEASE_DIR="build/macos/Build/Products/Release"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKGROUND="${SCRIPT_DIR}/dmg-background.png"

if [ ! -d "${RELEASE_DIR}/${APP_NAME}" ]; then
  echo "ERROR: Build output not found at ${RELEASE_DIR}/${APP_NAME}"
  echo "Run 'flutter build macos --release' first."
  exit 1
fi

if [ ! -f "${BACKGROUND}" ]; then
  echo "ERROR: DMG background not found at ${BACKGROUND}"
  exit 1
fi

if ! command -v create-dmg &>/dev/null; then
  echo "ERROR: create-dmg is not installed."
  echo "Install with: brew install create-dmg"
  exit 1
fi

# Remove any previous DMG with same name
rm -f "${DMG_NAME}"

# Build create-dmg arguments
CREATE_DMG_ARGS=(
  --volname "Ancient Anguish Client"
  --background "${BACKGROUND}"
  --window-pos 200 120
  --window-size 660 400
  --icon-size 80
  --icon "${APP_NAME}" 180 170
  --app-drop-link 480 170
  --no-internet-enable
)

if [ -n "$CODESIGN_IDENTITY" ]; then
  CREATE_DMG_ARGS+=(--codesign "$CODESIGN_IDENTITY")
fi

# create-dmg exits with code 2 when it cannot set the custom volume icon
# (happens without code signing). This is purely cosmetic — treat it as success.
set +e
create-dmg "${CREATE_DMG_ARGS[@]}" "${DMG_NAME}" "${RELEASE_DIR}/${APP_NAME}"
EXIT_CODE=$?
set -e

if [ -n "$CODESIGN_IDENTITY" ]; then
  # With code signing, all exit codes other than 0 are real errors
  if [ $EXIT_CODE -ne 0 ]; then
    echo "ERROR: create-dmg failed with exit code ${EXIT_CODE}"
    exit $EXIT_CODE
  fi
else
  # Without signing, exit code 2 (icon setting failure) is cosmetic
  if [ $EXIT_CODE -ne 0 ] && [ $EXIT_CODE -ne 2 ]; then
    echo "ERROR: create-dmg failed with exit code ${EXIT_CODE}"
    exit $EXIT_CODE
  fi
fi

echo "Built: ${DMG_NAME}"
