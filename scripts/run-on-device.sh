#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/run-on-device.sh [device-id]
# If device-id is omitted and only one device is connected, the script runs on that device.
# This script is intended to be executed on the host machine where the Android device is connected.

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/app"

echo "Switching to app directory: $APP_DIR"
cd "$APP_DIR"

echo "Ensure Flutter and ADB are installed on the host and in PATH."
command -v flutter >/dev/null 2>&1 || { echo "flutter not found in PATH" >&2; exit 2; }
command -v adb >/dev/null 2>&1 || { echo "adb not found in PATH. Install android-tools-adb or platform-tools." >&2; exit 3; }

echo "Running flutter pub get..."
flutter pub get

echo "Listing connected ADB devices..."
adb devices

# Try to list devices via flutter. If `jq` isn't available, fall back to parsing flutter devices output.
if command -v jq >/dev/null 2>&1; then
  DEVICES=( $(flutter devices --machine | jq -r '.[].id' 2>/dev/null || true) )
else
  mapfile -t DEVICES < <(flutter devices 2>/dev/null | awk '/•/ || /[a-z0-9]{4,}/' | awk 'NR>1{print $1}' ) || true
fi

if [ ${#DEVICES[@]} -eq 0 ]; then
  echo "No flutter devices found. Ensure your device is connected and authorized (adb devices)." >&2
  exit 4
fi

DEVICE_ARG="${1:-}"
if [ -n "$DEVICE_ARG" ]; then
  echo "Using device: $DEVICE_ARG"
  flutter run -d "$DEVICE_ARG"
else
  if [ ${#DEVICES[@]} -eq 1 ]; then
    echo "Single device detected: ${DEVICES[0]}. Running..."
    flutter run -d "${DEVICES[0]}"
  else
    echo "Multiple devices detected:" 
    flutter devices
    echo
    echo "Please re-run the script with the desired device id as the first argument. Example:" 
    echo "  bash scripts/run-on-device.sh emulator-5554"
    exit 5
  fi
fi
