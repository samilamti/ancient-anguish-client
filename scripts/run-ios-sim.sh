#!/usr/bin/env bash
# Boot an iOS simulator (if not already booted) and run the Flutter app on it.
# Usage:
#   bash scripts/run-ios-sim.sh                          # default: iPhone 16 Pro Max (6.9")
#   bash scripts/run-ios-sim.sh "iPhone 14 Plus"         # pick by name
#   bash scripts/run-ios-sim.sh "iPad Pro 13-inch (M4)"  # iPad target
# Tip: `xcrun simctl list devices available` lists valid names.
#
# App Store Connect native screenshot dimensions (pick the sim that matches the slot):
#   iPhone 6.9"  slot  (1320x2868) → iPhone 16 Pro Max
#   iPhone 6.5"  slot  (1284x2778) → iPhone 14 Plus or iPhone 13 Pro Max
#   iPhone 6.5"  slot  (1242x2688) → iPhone 11 Pro Max
#   iPad 13"     slot  (2064x2752) → iPad Pro 13-inch (M4)
# If the sim isn't installed, create it:
#   xcrun simctl create "iPhone 14 Plus" com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus \
#     com.apple.CoreSimulator.SimRuntime.iOS-18-6
set -euo pipefail

DEVICE_NAME="${1:-iPhone 16 Pro Max}"

UDID=$(xcrun simctl list devices available \
  | awk -F '[()]' -v name="$DEVICE_NAME" '
      $0 ~ name {
        for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F-]{36}$/) { print $i; exit }
      }')

if [[ -z "$UDID" ]]; then
  echo "No simulator matching: $DEVICE_NAME"
  echo "Available:"
  xcrun simctl list devices available | grep -E "iPhone|iPad" | sed 's/^/  /'
  exit 1
fi

STATE=$(xcrun simctl list devices | awk -v u="$UDID" '$0 ~ u { match($0, /\((Booted|Shutdown)\)/, m); print m[1]; exit }')

if [[ "$STATE" != "Booted" ]]; then
  echo "=== Booting $DEVICE_NAME ($UDID) ==="
  xcrun simctl boot "$UDID"
fi

open -a Simulator --args -CurrentDeviceUDID "$UDID"

echo "=== Running on $DEVICE_NAME (debug, hot reload enabled) ==="
exec flutter run -d "$UDID"
