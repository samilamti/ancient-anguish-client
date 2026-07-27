#!/usr/bin/env bash
# Capture App Store screenshots of the seeded demo scenes (see
# lib/dev/demo_seed.dart). Each scene is a separate --dart-define=AA_DEMO
# build, because the seed is compile-time.
#
# Scenes: terminal | hints | kill | recent | rules
#
# Usage:
#   bash scripts/demo-screenshots.sh macos [scene ...]
#   bash scripts/demo-screenshots.sh ios <device-udid> [scene ...]
#
# With no scenes listed, all five are captured. Output lands in
# screenshots/{macos,ios}/<ts>-demo-<scene>-<slot>.png at the exact
# App Store pixel sizes (macOS 2880x1800, iPhone 6.5 1284x2778).
set -euo pipefail

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

PLATFORM="${1:-}"
shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAC_PROC="ancient_anguish_client"
MAC_APP="$ROOT/build/macos/Build/Products/Debug/ancient_anguish_client.app"
ALL_SCENES=(terminal hints kill recent rules)

# Seconds to wait after launch before capturing. The demo seeder waits ~0.9s
# post-frame before opening its sheet, so give the app comfortably longer.
SETTLE=10

usage() {
  echo "Usage: $0 macos [scene ...]" >&2
  echo "       $0 ios <device-udid> [scene ...]" >&2
  exit 1
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

capture_ios() {
  local udid="$1" scene="$2"
  local ts out
  ts="$(date +%Y%m%d-%H%M%S)"
  out="$ROOT/screenshots/ios/${ts}-demo-${scene}-iphone-6.5.png"
  mkdir -p "$(dirname "$out")"

  echo "==> iOS / $scene: building + installing"
  # `flutter run` is the only path that applies --dart-define and installs in
  # one step; it is backgrounded and killed once the shot is taken.
  (cd "$ROOT" && flutter run -d "$udid" --dart-define="AA_DEMO=$scene" \
      >/tmp/aa-demo-$scene.log 2>&1) &
  local runpid=$!

  # Wait for the app to appear on screen rather than guessing a build time.
  local waited=0
  while ! grep -q "Flutter run key commands\|Syncing files" /tmp/aa-demo-$scene.log 2>/dev/null; do
    sleep 5
    waited=$((waited + 5))
    if [[ $waited -ge 600 ]]; then
      echo "    timed out waiting for flutter run; see /tmp/aa-demo-$scene.log" >&2
      kill $runpid 2>/dev/null || true
      return 1
    fi
  done
  sleep "$SETTLE"

  xcrun simctl io "$udid" screenshot "$out"
  verify "$out" 1284 2778
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
    [[ ${#scenes[@]} -eq 0 ]] && scenes=("${ALL_SCENES[@]}")
    for scene in "${scenes[@]}"; do capture_macos "$scene"; done
    ;;
  ios)
    UDID="${1:-}"; shift || true
    [[ -z "$UDID" ]] && usage
    scenes=("$@")
    [[ ${#scenes[@]} -eq 0 ]] && scenes=("${ALL_SCENES[@]}")
    for scene in "${scenes[@]}"; do capture_ios "$UDID" "$scene"; done
    ;;
  *) usage ;;
esac

echo "Done."
