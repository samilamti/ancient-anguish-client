#!/usr/bin/env bash
# One-command Android release: derive versionCode from pubspec, build the
# release AAB, and hand off to publish-aab.sh (dry run unless --go).
#
#   bash scripts/play/release-android.sh                 # build + validate
#   bash scripts/play/release-android.sh --go            # build + publish (internal)
#   bash scripts/play/release-android.sh --track alpha --notes "..." --go
#
# versionCode scheme: major*10000 + minor*100 + patch (6.19.0 -> 61900),
# strictly increasing as long as pubspec's version goes up.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR/../.."

VER=$(grep '^version:' pubspec.yaml | awk '{print $2}')
NAME=${VER%%+*}
MA=$(echo "$NAME" | cut -d. -f1)
MI=$(echo "$NAME" | cut -d. -f2)
PA=$(echo "$NAME" | cut -d. -f3)
VC=$((10#$MA * 10000 + 10#$MI * 100 + 10#$PA))

echo "=== Building AAB v$NAME (versionCode $VC) ==="
flutter build appbundle --release --build-number="$VC"

exec bash "$SCRIPT_DIR/publish-aab.sh" "$@"
