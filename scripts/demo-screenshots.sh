#!/usr/bin/env bash
# Capture App Store screenshots of the seeded demo scenes (see
# lib/dev/demo_seed.dart). Each scene is a separate --dart-define=AA_DEMO
# build, because the seed is compile-time.
#
# Scenes: terminal | hints | kill | recent | rules
#
# Usage:
#   bash scripts/demo-screenshots.sh macos                 [scene ...]
#   bash scripts/demo-screenshots.sh ios     <device-udid> [scene ...]
#   bash scripts/demo-screenshots.sh ipad    <device-udid> [scene ...]
#   bash scripts/demo-screenshots.sh android [serial]      [scene ...]
#
# With no scenes listed, every scene valid for that platform is captured —
# `hints` is skipped on macOS and iPad, whose widths (>=768) get the desktop
# layout, where TAB drives completion and the Hints bar doesn't render.
#
# Output lands in screenshots/{macos,ios,android}/<ts>-demo-<scene>-<slot>.png
# at the exact store pixel sizes:
#   macOS      2880x1800  (App Store APP_DESKTOP)
#   iPhone 6.5 1284x2778  (App Store APP_IPHONE_65)
#   iPad 13"   2064x2752  (App Store APP_IPAD_PRO_3GEN_129)
#   Android    1080x2400  (Play phone screenshots, 9:20)
set -euo pipefail

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

PLATFORM="${1:-}"
shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAC_PROC="ancient_anguish_client"
MAC_APP="$ROOT/build/macos/Build/Products/Debug/ancient_anguish_client.app"
ALL_SCENES=(terminal hints kill recent rules)
# Wide layouts (>=768pt) render the desktop UI, which has no Hints bar.
WIDE_SCENES=(terminal kill recent rules)
ADB="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/platform-tools/adb"
ANDROID_APP_ID="org.ancientanguish.ancient_anguish_client"

# Seconds to wait after launch before capturing. The demo seeder waits ~0.9s
# post-frame before opening its sheet, so give the app comfortably longer.
SETTLE=10

usage() {
  echo "Usage: $0 macos                 [scene ...]" >&2
  echo "       $0 ios     <device-udid> [scene ...]" >&2
  echo "       $0 ipad    <device-udid> [scene ...]" >&2
  echo "       $0 android [serial]      [scene ...]" >&2
  exit 1
}

# Waits for `flutter run` to report the app is up, rather than guessing a
# build time. Args: <log-path> <pid>
wait_for_flutter_run() {
  local log="$1" runpid="$2" waited=0
  while ! grep -q "Flutter run key commands\|Syncing files" "$log" 2>/dev/null; do
    sleep 5
    waited=$((waited + 5))
    if [[ $waited -ge 900 ]]; then
      echo "    timed out waiting for flutter run; see $log" >&2
      kill "$runpid" 2>/dev/null || true
      return 1
    fi
  done
  return 0
}

capture_macos() {
  local scene="$1"
  local ts out
  ts="$(date +%Y%m%d-%H%M%S)"
  out="$ROOT/screenshots/macos/${ts}-demo-${scene}-macos.png"
  mkdir -p "$(dirname "$out")"

  echo "==> macOS / $scene: building"
  (cd "$ROOT" && flutter build macos --debug --dart-define="AA_DEMO=$scene" >/dev/null)

  pkill -f "$MAC_PROC" 2>/dev/null || true
  sleep 1
  open "$MAC_APP"
  sleep "$SETTLE"

  # Retina 1440x900 logical points = the 2880x1800 App Store desktop slot.
  osascript >/dev/null 2>&1 <<AS || true
tell application "System Events"
  tell process "$MAC_PROC"
    set frontmost to true
    set position of window 1 to {20, 40}
    set size of window 1 to {1440, 900}
    perform action "AXRaise" of window 1
  end tell
end tell
AS
  sleep 2
  screencapture -x -R 20,40,1440,900 "$out"
  verify "$out" 2880 1800
  echo "    $out"
}

# Shared iOS/iPadOS capture. Args: <udid> <scene> <slot> <want-w> <want-h>
capture_simulator() {
  local udid="$1" scene="$2" slot="$3" want_w="$4" want_h="$5"
  local ts out log
  ts="$(date +%Y%m%d-%H%M%S)"
  out="$ROOT/screenshots/ios/${ts}-demo-${scene}-${slot}.png"
  log="/tmp/aa-demo-${slot}-${scene}.log"
  mkdir -p "$(dirname "$out")"

  echo "==> $slot / $scene: building + installing"
  # `flutter run` is the only path that applies --dart-define and installs in
  # one step; it is backgrounded and killed once the shot is taken.
  (cd "$ROOT" && flutter run -d "$udid" --dart-define="AA_DEMO=$scene" \
      >"$log" 2>&1) &
  local runpid=$!
  wait_for_flutter_run "$log" $runpid || return 1
  sleep "$SETTLE"

  xcrun simctl io "$udid" screenshot "$out" >/dev/null 2>&1
  verify "$out" "$want_w" "$want_h"
  echo "    $out"

  kill $runpid 2>/dev/null || true
  wait $runpid 2>/dev/null || true
}

capture_android() {
  local serial="$1" scene="$2"
  local ts out log
  ts="$(date +%Y%m%d-%H%M%S)"
  out="$ROOT/screenshots/android/${ts}-demo-${scene}-android.png"
  log="/tmp/aa-demo-android-${scene}.log"
  mkdir -p "$(dirname "$out")"

  echo "==> android / $scene: building + installing"
  (cd "$ROOT" && flutter run -d "$serial" --dart-define="AA_DEMO=$scene" \
      >"$log" 2>&1) &
  local runpid=$!
  wait_for_flutter_run "$log" $runpid || return 1
  sleep "$SETTLE"

  # `exec-out` keeps the PNG binary-clean; plain `shell screencap` mangles
  # it with CRLF translation on some adb/emulator combinations.
  "$ADB" -s "$serial" exec-out screencap -p > "$out"
  verify "$out" 1080 2400
  echo "    $out"

  kill $runpid 2>/dev/null || true
  wait $runpid 2>/dev/null || true
}

verify() {
  local path="$1" want_w="$2" want_h="$3"
  command -v sips >/dev/null 2>&1 || return 0
  local got_w got_h
  got_w=$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ {print $2}')
  got_h=$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ {print $2}')
  if [[ "$got_w" != "$want_w" || "$got_h" != "$want_h" ]]; then
    echo "    warn: captured ${got_w}x${got_h}, App Store wants ${want_w}x${want_h}" >&2
  fi
}

case "$PLATFORM" in
  macos)
    scenes=("$@")
    [[ ${#scenes[@]} -eq 0 ]] && scenes=("${WIDE_SCENES[@]}")
    for scene in "${scenes[@]}"; do capture_macos "$scene"; done
    ;;
  ios)
    UDID="${1:-}"; shift || true
    [[ -z "$UDID" ]] && usage
    scenes=("$@")
    [[ ${#scenes[@]} -eq 0 ]] && scenes=("${ALL_SCENES[@]}")
    for scene in "${scenes[@]}"; do
      capture_simulator "$UDID" "$scene" "iphone-6.5" 1284 2778
    done
    ;;
  ipad)
    UDID="${1:-}"; shift || true
    [[ -z "$UDID" ]] && usage
    scenes=("$@")
    [[ ${#scenes[@]} -eq 0 ]] && scenes=("${WIDE_SCENES[@]}")
    for scene in "${scenes[@]}"; do
      capture_simulator "$UDID" "$scene" "ipad-13" 2064 2752
    done
    ;;
  android)
    # Serial is optional: with one emulator running, resolve it ourselves.
    SERIAL=""
    if [[ "${1:-}" == emulator-* || "${1:-}" == *:* ]]; then
      SERIAL="$1"; shift
    else
      SERIAL="$("$ADB" devices | awk '/\tdevice$/ {print $1; exit}')"
    fi
    if [[ -z "$SERIAL" ]]; then
      echo "No Android device/emulator attached. Boot one with:" >&2
      echo "  bash scripts/run-android-emu.sh Medium_Phone" >&2
      exit 1
    fi
    echo "Using Android device: $SERIAL"
    scenes=("$@")
    [[ ${#scenes[@]} -eq 0 ]] && scenes=("${ALL_SCENES[@]}")
    for scene in "${scenes[@]}"; do capture_android "$SERIAL" "$scene"; done
    ;;
  *) usage ;;
esac

echo "Done."
