#!/usr/bin/env bash
# Capture a PNG screenshot from the booted iOS simulator, Android emulator,
# or the running macOS app window.
# Saves to screenshots/{ios,android,macos}/<timestamp>-<label>.png
# Usage:
#   bash scripts/screenshot.sh                          # auto-detect, no label
#   bash scripts/screenshot.sh ios support-hero         # iOS, label=support-hero
#   bash scripts/screenshot.sh macos support-hero       # macOS app window
#   bash scripts/screenshot.sh android quick-commands   # Android
#   bash scripts/screenshot.sh auto combat              # auto-detect platform
set -euo pipefail

PLATFORM="${1:-auto}"
LABEL="${2:-shot}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

MAC_PROC="ancient_anguish_client"

shoot_ios() {
  local out="$ROOT/screenshots/ios/${TS}-${LABEL}.png"
  mkdir -p "$(dirname "$out")"
  xcrun simctl io booted screenshot "$out"
  echo "$out"
}

shoot_android() {
  local adb="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/platform-tools/adb"
  local out="$ROOT/screenshots/android/${TS}-${LABEL}.png"
  mkdir -p "$(dirname "$out")"
  "$adb" exec-out screencap -p > "$out"
  echo "$out"
}

shoot_macos() {
  local out="$ROOT/screenshots/macos/${TS}-${LABEL}.png"
  mkdir -p "$(dirname "$out")"
  # Resolve the front window of our process via AppleScript. If that fails
  # (e.g. app not running under that bundle name), fall back to full screen.
  local win_id
  win_id=$(osascript -e "tell application \"System Events\" to tell process \"${MAC_PROC}\" to id of window 1" 2>/dev/null || true)
  if [[ -n "$win_id" ]]; then
    screencapture -x -l "$win_id" "$out"
  else
    echo "Warning: couldn't find window for process '${MAC_PROC}'. Capturing full screen." >&2
    screencapture -x "$out"
  fi
  echo "$out"
}

has_ios() { xcrun simctl list devices 2>/dev/null | grep -q '(Booted)'; }
has_android() {
  local adb="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/platform-tools/adb"
  [[ -x "$adb" ]] && "$adb" devices 2>/dev/null | grep -q "device$"
}
has_macos() { pgrep -x "$MAC_PROC" >/dev/null 2>&1; }

case "$PLATFORM" in
  ios)     shoot_ios ;;
  android) shoot_android ;;
  macos)   shoot_macos ;;
  auto)
    if has_ios; then
      shoot_ios
    elif has_macos; then
      shoot_macos
    elif has_android; then
      shoot_android
    else
      echo "No booted iOS simulator, Android emulator, or macOS app window found." >&2
      exit 1
    fi
    ;;
  *) echo "Usage: $0 [ios|android|macos|auto] [label]" >&2; exit 1 ;;
esac
