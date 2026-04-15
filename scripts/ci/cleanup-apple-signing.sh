#!/usr/bin/env bash
# Clean up Apple signing artifacts created by setup-apple-signing.sh.
# Safe to run even if setup was partial or never ran.
set -euo pipefail

KEYCHAIN_NAME="${SIGNING_KEYCHAIN_NAME:-signing.keychain-db}"

echo "=== Cleaning up Apple signing ==="

# Remove the temporary keychain
if security list-keychains | grep -q "$KEYCHAIN_NAME"; then
  echo "  Deleting keychain: $KEYCHAIN_NAME"
  security delete-keychain "$KEYCHAIN_NAME"
fi

# Remove provisioning profiles installed by CI
PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
if [ -d "$PROFILES_DIR" ]; then
  # Remove profiles installed by our setup script (CI runners are ephemeral,
  # but clean up anyway for self-hosted runners or local testing)
  find "$PROFILES_DIR" -name "*.mobileprovision" -newer /tmp -delete 2>/dev/null || true
  find "$PROFILES_DIR" -name "*.provisionprofile" -newer /tmp -delete 2>/dev/null || true
fi

# Remove App Store Connect API key
ASC_KEY_DIR="$HOME/.private_keys"
if [ -d "$ASC_KEY_DIR" ]; then
  echo "  Removing API key directory"
  rm -rf "$ASC_KEY_DIR"
fi

echo "=== Cleanup complete ==="
