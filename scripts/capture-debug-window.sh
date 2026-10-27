#!/usr/bin/env bash
# Resize and screenshot THIS checkout's running debug client, by pid, without
# touching any other copy (notably the installed /Applications client Sami may
# be playing on, which preview-macos.sh kills).
#
#   scripts/capture-debug-window.sh <out.png> [WIDTHxHEIGHT]   default 1280x800
#
# Typical review loop (demo scene, no MUD needed):
#   flutter build macos --debug --dart-define=AA_DEMO=terminal
#   open -n build/macos/Build/Products/Debug/ancient_anguish_client.app
#   scripts/capture-debug-window.sh /tmp/desk.png 1280x800
#   scripts/capture-debug-window.sh /tmp/phone.png 390x800   # phone layout (<768pt)
#
# Width below 768pt switches the client to its phone layout. The PNG comes out
# at Retina scale (2x the logical size). A black image means the Mac is locked.
# Used for the 2026-10-27 UI review; proven end to end on macOS 26.
set -euo pipefail

out="${1:?usage: capture-debug-window.sh <out.png> [WIDTHxHEIGHT]}"
size="${2:-1280x800}"
w="${size%x*}"
h="${size#*x}"

root=$(cd "$(dirname "$0")/.." && pwd)
pid=$(pgrep -f "^$root/build/macos/Build/Products/Debug/ancient_anguish_client.app/Contents/MacOS/ancient_anguish_client\$" | head -1 || true)
[ -n "$pid" ] || { echo "No debug client from this checkout is running." >&2; exit 1; }

proc="(first process whose unix id is $pid)"
osascript -e "tell application \"System Events\" to tell $proc to set frontmost to true" \
  -e "tell application \"System Events\" to tell $proc to set position of window 1 to {60, 60}" \
  -e "tell application \"System Events\" to tell $proc to set size of window 1 to {$w, $h}" >/dev/null
sleep 1.5
# Raise again: the installed client raises itself on incoming tells, and -R
# captures whatever is on top of the rectangle.
osascript -e "tell application \"System Events\" to tell $proc to set frontmost to true" >/dev/null
geom=$(osascript -e "tell application \"System Events\" to tell $proc to get (position of window 1) & (size of window 1)")
IFS=', ' read -r x y gw gh <<< "$geom"
screencapture -x -R"${x},${y},${gw},${gh}" "$out"
echo "$out (${gw}x${gh} pt)"
