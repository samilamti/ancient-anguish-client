#!/usr/bin/env bash
# Refuses to continue when a local-only feature marker is present, so a
# release built on this machine can never bundle it.
#
#   bash scripts/check-no-local-features.sh            # check the checkout
#   bash scripts/check-no-local-features.sh app.aab    # check a built artifact
#
# Markers live in assets/local/ (gitignored apart from .gitkeep). Anything else
# in there gets bundled into the app by pubspec's `assets/local/` entry, so any
# file other than .gitkeep counts. An artifact (.aab/.apk/.ipa/.zip) is checked
# by listing its contents, which also catches a build made before the marker
# was removed.
set -euo pipefail

# Resolve the artifact before changing directory, so a relative path still works.
artifact=""
if [ $# -gt 0 ]; then
  artifact=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
fi
cd "$(dirname "$0")/.."

if [ -n "$artifact" ]; then
  hits=$(unzip -Z1 "$artifact" | grep 'flutter_assets/assets/local/' | grep -v '/\.gitkeep$' || true)
  where="$artifact"
else
  hits=$(find assets/local -type f ! -name .gitkeep 2>/dev/null || true)
  where="assets/local/"
fi

if [ -n "$hits" ]; then
  echo "Refusing: local-only feature markers found in $where" >&2
  echo "$hits" | sed 's/^/  /' >&2
  echo "Move them out of the way before building a release." >&2
  exit 1
fi
