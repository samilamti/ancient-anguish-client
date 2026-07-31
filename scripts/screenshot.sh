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
#
# macOS: prefers the client built from THIS checkout (build/macos) over an
# installed /Applications copy, and raises it before capturing — see
# project_macos_pid() for why that matters when both are running.
set -euo pipefail

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

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

# PID of the client built from THIS checkout, or empty if it isn't running.
#
# Two instances are routinely up at once: the installed release build in
# /Applications (often mid-game) and the debug build under build/macos. They
# share a process name, so `tell process "<name>"` resolves whichever the OS
# lists first — which means a store-shot run can silently capture a live
# session instead of the build under test. Match on the executable path.
project_macos_pid() {
  pgrep -f "^${ROOT}/build/macos/.*/${MAC_PROC}\$" 2>/dev/null | head -1 || true
}

shoot_macos() {
  local out="$ROOT/screenshots/macos/${TS}-${LABEL}.png"
  mkdir -p "$(dirname "$out")"

  local pid target geom
  pid="$(project_macos_pid)"
  if [ -n "$pid" ]; then
    target="(first process whose unix id is ${pid})"
  else
    local others
    others=$(pgrep -x "$MAC_PROC" 2>/dev/null | tr '\n' ' ' || true)
    if [ -n "$others" ]; then
      echo "Warning: no client running from this checkout (build/macos). Falling back to" >&2
      echo "         another instance (pids: $others) — this may be a live session, and" >&2
      echo "         will NOT show changes you just built. Run scripts/run-macos.sh first." >&2
    fi
    target="process \"${MAC_PROC}\""
  fi

  # Raise before measuring and capturing. Required, not cosmetic: the region
  # capture below grabs whatever is on top of those coordinates, and the other
  # instance raises itself unprompted (an incoming tell calls
  # WindowService.requestAttention). Capture immediately after — don't sleep.
  osascript -e "tell application \"System Events\" to tell ${target} to set frontmost to true" >/dev/null 2>&1 || true

  # `id of window 1` is NOT a System Events property — it fails with -1728, so
  # `screencapture -l` is unavailable here (this is why the macOS path used to
  # silently capture the full screen every time). position + size do work, so
  # capture by region instead.
  geom=$(osascript -e "tell application \"System Events\" to tell ${target} to get position of window 1 & size of window 1" 2>/dev/null || true)

  if [ -n "$geom" ]; then
    local x y w h
    IFS=', ' read -r x y w h <<< "$geom"
    screencapture -x -R"${x},${y},${w},${h}" "$out"
  else
    echo "Warning: couldn't find window for process '${MAC_PROC}'. Capturing full screen." >&2
    echo "         A black or lock-screen image here means the Mac is locked, not that" >&2
    echo "         a permission was revoked." >&2
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
