#!/usr/bin/env bash
# Capture an App Store screenshot at a named device slot, naming the output
# <ts>-<label>-<slot>.png and (for macOS) pre-resizing the app window to the
# Retina-correct 1440x900 logical size before capture.
#
# Assumes the right simulator/emulator is already booted and the app is running
# with the correct --dart-define flags. Use scripts/run-ios-sim.sh / run-macos.sh
# to launch the app first.
#
# Slots (enforced by App Store Connect):
#   iphone-6.9   1320x2868  iPhone 16 Pro Max
#   iphone-6.5   1284x2778  iPhone 14 Plus
#   ipad-13      2064x2752  iPad Pro 13-inch (M4)
#   macos        2880x1800  native window at 1440x900 logical points
#
# Usage:
#   bash scripts/app-store-screenshots.sh <slot> <label>
#   bash scripts/app-store-screenshots.sh iphone-6.9 support-hero
#   bash scripts/app-store-screenshots.sh macos     support-active
set -euo pipefail

SLOT="${1:-}"
LABEL="${2:-}"

if [[ -z "$SLOT" || -z "$LABEL" ]]; then
  echo "Usage: $0 <iphone-6.9|iphone-6.5|ipad-13|macos> <label>" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
MAC_PROC="ancient_anguish_client"

expected_size() {
  case "$1" in
    iphone-6.9) echo "1320 2868" ;;
    iphone-6.5) echo "1284 2778" ;;
    ipad-13)    echo "2064 2752" ;;
    macos)      echo "2880 1800" ;;
    *) return 1 ;;
  esac
}

verify_size() {
  local path="$1" want_w="$2" want_h="$3"
  if ! command -v sips >/dev/null 2>&1; then return 0; fi
  local got_w got_h
  got_w=$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ {print $2}')
  got_h=$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ {print $2}')
  if [[ "$got_w" != "$want_w" || "$got_h" != "$want_h" ]]; then
    echo "  warn: captured ${got_w}x${got_h}, App Store requires ${want_w}x${want_h}" >&2
    return 1
  fi
  return 0
}

shoot_ios_slot() {
  local slot="$1" label="$2"
  local out="$ROOT/screenshots/ios/${TS}-${label}-${slot}.png"
  mkdir -p "$(dirname "$out")"

  if ! xcrun simctl list devices 2>/dev/null | grep -q '(Booted)'; then
    echo "No iOS simulator is booted. Start one with:" >&2
    echo "  bash scripts/run-ios-sim.sh" >&2
    exit 1
  fi
  xcrun simctl io booted screenshot "$out"
  read -r w h <<< "$(expected_size "$slot")"
  verify_size "$out" "$w" "$h" || true
  echo "$out"
}

shoot_macos() {
  local label="$1"
  local out="$ROOT/screenshots/macos/${TS}-${label}-macos.png"
  mkdir -p "$(dirname "$out")"

  if ! pgrep -x "$MAC_PROC" >/dev/null 2>&1; then
    echo "The macOS app ($MAC_PROC) is not running." >&2
    echo "Launch with:" >&2
    echo "  bash scripts/run-macos.sh --dart-define=AA_SUB_SEED=hero" >&2
    exit 1
  fi

  # Resize the front window to 1440x900 logical points (→ 2880x1800 on Retina)
  # and raise it so screencapture -R hits clean pixels.
  osascript <<OSA || true
tell application "$MAC_PROC" to activate
tell application "System Events"
  tell process "$MAC_PROC"
    set frontmost to true
    set position of window 1 to {20, 40}
    set size of window 1 to {1440, 900}
    perform action "AXRaise" of window 1
  end tell
end tell
OSA
  sleep 2

  screencapture -x -R 20,40,1440,900 "$out"
  read -r w h <<< "$(expected_size macos)"
  verify_size "$out" "$w" "$h" || true
  echo "$out"
}

case "$SLOT" in
  iphone-6.9|iphone-6.5|ipad-13) shoot_ios_slot "$SLOT" "$LABEL" ;;
  macos)                         shoot_macos "$LABEL" ;;
  *) echo "Unknown slot: $SLOT" >&2; exit 1 ;;
esac
