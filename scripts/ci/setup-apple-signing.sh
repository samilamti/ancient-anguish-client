#!/usr/bin/env bash
# Setup Apple code signing for CI.
#
# Required environment variables (set from GitHub Secrets):
#   APPLE_TEAM_ID                    - 10-character Apple Developer Team ID
#   ASC_KEY_ID                       - App Store Connect API Key ID
#   ASC_ISSUER_ID                    - App Store Connect Issuer ID
#   ASC_KEY_BASE64                   - App Store Connect .p8 key, base64-encoded
#
# For macOS Developer ID (direct distribution):
#   DEVELOPERID_CERT_BASE64          - Developer ID Application .p12, base64-encoded
#   DEVELOPERID_CERT_PASSWORD        - Password for above
#
# For App Store (iOS + macOS):
#   APPLE_DISTRIBUTION_CERT_BASE64   - Apple Distribution .p12, base64-encoded
#   APPLE_DISTRIBUTION_CERT_PASSWORD - Password for above
#
# For Mac App Store .pkg signing:
#   MAC_INSTALLER_CERT_BASE64        - Mac Installer Distribution .p12, base64-encoded
#   MAC_INSTALLER_CERT_PASSWORD      - Password for above
#
# For iOS:
#   IOS_PROFILE_BASE64               - iOS App Store provisioning profile, base64-encoded
#
# For macOS App Store:
#   MACOS_APPSTORE_PROFILE_BASE64    - macOS App Store provisioning profile, base64-encoded
#
# Usage:
#   source scripts/ci/setup-apple-signing.sh [--ios] [--macos-devid] [--macos-appstore]
#   (flags can be combined)
set -euo pipefail

KEYCHAIN_NAME="signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"

# Export for cleanup script
export SIGNING_KEYCHAIN_NAME="$KEYCHAIN_NAME"

# Parse flags
SETUP_IOS=false
SETUP_MACOS_DEVID=false
SETUP_MACOS_APPSTORE=false

for arg in "$@"; do
  case "$arg" in
    --ios)              SETUP_IOS=true ;;
    --macos-devid)      SETUP_MACOS_DEVID=true ;;
    --macos-appstore)   SETUP_MACOS_APPSTORE=true ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

# If no flags, set up everything
if ! $SETUP_IOS && ! $SETUP_MACOS_DEVID && ! $SETUP_MACOS_APPSTORE; then
  SETUP_IOS=true
  SETUP_MACOS_DEVID=true
  SETUP_MACOS_APPSTORE=true
fi

echo "=== Creating temporary keychain ==="
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

# Add to search list (prepend so it takes priority)
EXISTING_KEYCHAINS=$(security list-keychains -d user | tr -d '"' | tr '\n' ' ')
security list-keychains -d user -s "$KEYCHAIN_NAME" $EXISTING_KEYCHAINS
security default-keychain -s "$KEYCHAIN_NAME"

import_cert() {
  local name="$1"
  local base64_var="$2"
  local password_var="$3"
  local cert_path
  cert_path="$(mktemp /tmp/cert-XXXXXX.p12)"

  echo "  Importing $name certificate..."

  # Decode base64. Use printf (not echo) to avoid backslash interpretation.
  # Strip any surrounding whitespace/newlines from the secret first.
  local b64_value="${!base64_var}"
  b64_value="${b64_value//$'\r'/}"
  b64_value="${b64_value//$'\n'/}"
  printf '%s' "$b64_value" | base64 --decode > "$cert_path"

  # Verify the .p12 decoded to a reasonable size
  local cert_size
  cert_size=$(stat -f%z "$cert_path" 2>/dev/null || stat -c%s "$cert_path")
  if [ "$cert_size" -lt 500 ]; then
    echo "    ERROR: decoded .p12 is only ${cert_size} bytes — base64 secret looks wrong or truncated"
    rm -f "$cert_path"
    exit 1
  fi
  echo "    .p12 size: ${cert_size} bytes"

  # Strip only trailing CR/LF from password (preserves leading/trailing spaces
  # in case the real password has them, but kills the common \n paste artifact)
  local pw="${!password_var}"
  pw="${pw%$'\r'}"
  pw="${pw%$'\n'}"
  pw="${pw%$'\r'}"

  if ! security import "$cert_path" \
    -k "$KEYCHAIN_NAME" \
    -P "$pw" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -T /usr/bin/productbuild \
    -T /usr/bin/productsign 2>&1; then
    echo ""
    echo "    ERROR: $name import failed."
    echo "    Common causes:"
    echo "      1. Trailing whitespace/newline in the ${password_var} secret."
    echo "      2. Curly quotes (' ' \" \") from a password manager — retype the password."
    echo "      3. .p12 was exported from openssl 3.x — re-export from Keychain Access"
    echo "         (File > Export Items) or add '-legacy' to openssl pkcs12 command."
    echo "      4. Wrong password."
    rm -f "$cert_path"
    exit 1
  fi
  rm -f "$cert_path"
}

echo "=== Importing certificates ==="

if $SETUP_MACOS_DEVID; then
  import_cert "Developer ID Application" DEVELOPERID_CERT_BASE64 DEVELOPERID_CERT_PASSWORD
fi

if $SETUP_IOS || $SETUP_MACOS_APPSTORE; then
  import_cert "Apple Distribution" APPLE_DISTRIBUTION_CERT_BASE64 APPLE_DISTRIBUTION_CERT_PASSWORD
fi

if $SETUP_MACOS_APPSTORE; then
  import_cert "Mac Installer Distribution" MAC_INSTALLER_CERT_BASE64 MAC_INSTALLER_CERT_PASSWORD
fi

# Allow codesign to access keys without UI prompt
echo "=== Setting key partition list ==="
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

# Install provisioning profiles
PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PROFILES_DIR"

if $SETUP_IOS && [ -n "${IOS_PROFILE_BASE64:-}" ]; then
  echo "=== Installing iOS provisioning profile ==="
  IOS_PROFILE_PATH="$PROFILES_DIR/ios_appstore.mobileprovision"
  echo "$IOS_PROFILE_BASE64" | base64 --decode > "$IOS_PROFILE_PATH"
  # Extract the profile UUID and rename to UUID.mobileprovision (required by Xcode)
  IOS_PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print UUID" /dev/stdin <<< "$(security cms -D -i "$IOS_PROFILE_PATH")")
  mv "$IOS_PROFILE_PATH" "$PROFILES_DIR/$IOS_PROFILE_UUID.mobileprovision"
  echo "  Installed iOS profile: $IOS_PROFILE_UUID"
  echo "IOS_PROFILE_UUID=$IOS_PROFILE_UUID" >> "${GITHUB_ENV:-/dev/null}"
fi

if $SETUP_MACOS_APPSTORE && [ -n "${MACOS_APPSTORE_PROFILE_BASE64:-}" ]; then
  echo "=== Installing macOS App Store provisioning profile ==="
  MACOS_PROFILE_PATH="$PROFILES_DIR/macos_appstore.provisionprofile"
  echo "$MACOS_APPSTORE_PROFILE_BASE64" | base64 --decode > "$MACOS_PROFILE_PATH"
  MACOS_PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print UUID" /dev/stdin <<< "$(security cms -D -i "$MACOS_PROFILE_PATH")")
  mv "$MACOS_PROFILE_PATH" "$PROFILES_DIR/$MACOS_PROFILE_UUID.provisionprofile"
  echo "  Installed macOS profile: $MACOS_PROFILE_UUID"
  echo "MACOS_PROFILE_UUID=$MACOS_PROFILE_UUID" >> "${GITHUB_ENV:-/dev/null}"
fi

# Write App Store Connect API key to disk for xcrun tools
if [ -n "${ASC_KEY_BASE64:-}" ]; then
  echo "=== Setting up App Store Connect API key ==="
  ASC_KEY_DIR="$HOME/.private_keys"
  mkdir -p "$ASC_KEY_DIR"
  ASC_KEY_PATH="$ASC_KEY_DIR/AuthKey_${ASC_KEY_ID}.p8"
  echo "$ASC_KEY_BASE64" | base64 --decode > "$ASC_KEY_PATH"
  echo "  API key written to $ASC_KEY_PATH"
  echo "ASC_KEY_PATH=$ASC_KEY_PATH" >> "${GITHUB_ENV:-/dev/null}"
fi

echo "=== Apple signing setup complete ==="
