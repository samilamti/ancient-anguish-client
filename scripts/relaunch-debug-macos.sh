#!/usr/bin/env bash
# Rebuild the macOS DEBUG client and (re)launch it so Sami can try a change.
#
# Usage:
#   bash scripts/relaunch-debug-macos.sh             # build, replace debug copy, open
#   bash scripts/relaunch-debug-macos.sh --no-build  # just replace + open
#
# Why a script: `open` on an already-running bundle only raises the OLD
# process, so a rebuilt app is not picked up until the old debug instance is
# killed. Only the debug copy under build/ is killed; the installed release
# app in /Applications (often mid-game) is never touched. Prints the new
# process's start time so you can confirm it postdates the build.
set -euo pipefail
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
APP="build/macos/Build/Products/Debug/ancient_anguish_client.app"
PATTERN="Debug/ancient_anguish_client.app/Contents/MacOS"

BUILD=1
[ "${1:-}" = "--no-build" ] && BUILD=0

if [ "$BUILD" -eq 1 ]; then
  flutter build macos --debug
fi

if pgrep -f "$PATTERN" >/dev/null; then
  echo "Stopping the running debug instance..."
  pkill -f "$PATTERN" || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -f "$PATTERN" >/dev/null || break
    sleep 0.5
  done
fi

open "$APP"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pid=$(pgrep -f "$PATTERN" || true)
  [ -n "$pid" ] && break
  sleep 0.5
done
if [ -z "${pid:-}" ]; then
  echo "ERROR: debug app did not start" >&2
  exit 1
fi
echo "Debug client running, pid $pid, started $(ps -o lstart= -p "$pid")"
