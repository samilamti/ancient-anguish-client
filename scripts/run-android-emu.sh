#!/usr/bin/env bash
# Boot an Android emulator (if not already running) and run the Flutter app on it.
# Usage:
#   bash scripts/run-android-emu.sh                   # default: Medium_Phone
#   bash scripts/run-android-emu.sh Small_Phone       # pick AVD by name
# Tip: `~/Library/Android/sdk/emulator/emulator -list-avds` lists valid names.
set -euo pipefail

AVD="${1:-Medium_Phone}"

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
EMULATOR="$SDK/emulator/emulator"
ADB="$SDK/platform-tools/adb"

if [[ ! -x "$EMULATOR" ]]; then
  echo "Android emulator not found at: $EMULATOR"
  echo "Set ANDROID_SDK_ROOT or install via Android Studio > SDK Manager."
  exit 1
fi

if ! "$EMULATOR" -list-avds | grep -qx "$AVD"; then
  echo "No AVD named '$AVD'. Available:"
  "$EMULATOR" -list-avds | sed 's/^/  /'
  echo "Create one via Android Studio > Device Manager."
  exit 1
fi

if ! "$ADB" devices | grep -q "emulator-.*device$"; then
  echo "=== Booting AVD: $AVD ==="
  "$EMULATOR" -avd "$AVD" -netdelay none -netspeed full >/tmp/emulator-$AVD.log 2>&1 &
  echo "Waiting for emulator to come online..."
  "$ADB" wait-for-device
  until [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
    sleep 2
  done
  echo "=== Emulator ready ==="
fi

DEVICE_ID=$("$ADB" devices | awk '/emulator-.*device$/ {print $1; exit}')

echo "=== Running on $DEVICE_ID (debug, hot reload enabled) ==="
exec flutter run -d "$DEVICE_ID"
