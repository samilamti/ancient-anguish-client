#!/usr/bin/env bash
# Build the macOS app, launch it at a chosen window size, and screenshot it.
#
# Exists because "does this look right on a phone?" is answerable on the Mac:
# the client switches to its mobile layout below 768pt of width, so a narrow
# macOS window exercises the phone UI without a simulator or a device. Used to
# verify the mobile compass strip and the docked battle HUD.
#
# Usage:
#   bash scripts/preview-macos.sh                      # 390x800 (phone), full window shot
#   bash scripts/preview-macos.sh --size 1280x800      # desktop layout
#   bash scripts/preview-macos.sh --demo terminal      # seed AA_DEMO scenes (no MUD needed)
#   bash scripts/preview-macos.sh --crop 0,95,400,60   # x,y,w,h relative to the window
#   bash scripts/preview-macos.sh --no-build           # reuse the existing bundle
#   bash scripts/preview-macos.sh --out /tmp/shot.png
#
# Notes / hard-won details:
#   * A LOCKED Mac looks exactly like revoked Screen Recording permission —
#     `screencapture` returns a black PNG or "could not create image from rect".
#     `caffeinate` below holds the display awake for the run; it cannot unlock.
#   * Release and debug builds share the process name `ancient_anguish_client`,
#     so any running copy is killed first rather than guessed between.
#   * The window is positioned at a known origin so --crop can be expressed in
#     window coordinates instead of screen ones.
#   * Coordinate CLICKING via AppleScript is unreliable here (tried twice, both
#     silently no-ops) — this script deliberately only positions and captures.
set -euo pipefail

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIZE="390x800"
DEMO=""
CROP=""
OUT=""
BUILD=1
ORIGIN_X=60
ORIGIN_Y=60

while [ $# -gt 0 ]; do
  case "$1" in
    --size)     SIZE="$2"; shift 2 ;;
    --demo)     DEMO="$2"; shift 2 ;;
    --crop)     CROP="$2"; shift 2 ;;
    --out)      OUT="$2"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    -h|--help)  sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

WIN_W="${SIZE%x*}"
WIN_H="${SIZE#*x}"
[ -n "$OUT" ] || OUT="$ROOT/build/preview-${WIN_W}x${WIN_H}.png"
mkdir -p "$(dirname "$OUT")"

APP="build/macos/Build/Products/Debug/ancient_anguish_client.app"

if [ "$BUILD" -eq 1 ]; then
  echo "=== building (debug${DEMO:+, AA_DEMO=$DEMO}) ==="
  if [ -n "$DEMO" ]; then
    flutter build macos --debug --dart-define="AA_DEMO=$DEMO"
  else
    flutter build macos --debug
  fi
fi

[ -d "$APP" ] || { echo "No app bundle at $APP — drop --no-build." >&2; exit 1; }

# Both build flavours share this process name; kill any of them.
pkill -f ancient_anguish_client >/dev/null 2>&1 || true
sleep 1

# Hold the display awake: a screen that sleeps (and then locks) fails every
# capture below in ways that look like a permissions problem.
caffeinate -d -i -t 300 &
CAFFEINATE_PID=$!
trap 'kill "$CAFFEINATE_PID" >/dev/null 2>&1 || true' EXIT

echo "=== launching at ${WIN_W}x${WIN_H} ==="
open "$APP"
sleep 7

# Position, front, and then READ BACK the geometry. The `try` blocks below
# swallow their own errors, so this step exits 0 even when it did nothing at
# all — and the capture then silently photographs whatever other window happens
# to sit at those screen coordinates. Verifying is the difference between a
# screenshot of the app and a screenshot of your editor.
GEOM="$(osascript 2>/dev/null <<AS || true
tell application "System Events"
  set out to "none"
  repeat with p in (every process whose name contains "ancient_anguish")
    try
      set frontmost of p to true
      set w to window 1 of p
      set position of w to {$ORIGIN_X, $ORIGIN_Y}
      set size of w to {$WIN_W, $WIN_H}
      perform action "AXRaise" of w
      delay 0.5
      set pos to position of w
      set sz to size of w
      set out to (item 1 of pos as text) & "," & (item 2 of pos as text) & "," & (item 1 of sz as text) & "," & (item 2 of sz as text)
    end try
  end repeat
  return out
end tell
AS
)"

if [ "$GEOM" != "$ORIGIN_X,$ORIGIN_Y,$WIN_W,$WIN_H" ]; then
  echo "error: window is at '${GEOM:-none}', expected '$ORIGIN_X,$ORIGIN_Y,$WIN_W,$WIN_H'." >&2
  echo "       The capture would have photographed whatever else is there." >&2
  echo "       Usually: the app needed longer to open, or macOS is withholding" >&2
  echo "       Accessibility permission for System Events." >&2
  exit 1
fi
echo "=== window at $GEOM ==="
sleep 1

if [ -n "$CROP" ]; then
  IFS=, read -r CX CY CW CH <<<"$CROP"
  REGION="$((ORIGIN_X + CX)),$((ORIGIN_Y + CY)),${CW},${CH}"
else
  # A little slack around the frame so the shadow and title bar aren't clipped.
  REGION="$((ORIGIN_X - 5)),$((ORIGIN_Y - 5)),$((WIN_W + 10)),$((WIN_H + 10))"
fi

echo "=== capturing region $REGION ==="
screencapture -x -R "$REGION" "$OUT"

# An all-black or truncated capture is the signature of a locked or sleeping
# display, not a bug in the app — the three symptoms (black PNG, "could not
# create image from rect", and AppleScript "Invalid index") all point at the
# wrong culprit. Look at the file before believing what it shows.
if [ ! -s "$OUT" ]; then
  echo "error: capture is empty — is the display asleep or the Mac locked?" >&2
  exit 1
fi

echo "Wrote $OUT"
