#!/bin/bash
# Installs and runs the app on whichever device is currently connected over
# ADB (wireless or USB) — no need to know its IP:port, it auto-detects.
#
#   ./run_dev.sh          cloud mode (default): talks to the backend below
#   ./run_dev.sh local    local mode: on-device SQLite, no backend needed
#
# BACKEND_URL below is the Mac's LAN IP running the backend (`node
# src/server.js` in ../backend). If the phone can't reach the backend after
# this runs, your Mac's IP may have changed — check it with:
#   ipconfig getifaddr en0
# and update BACKEND_URL below to match. (Ignored in local mode.)

set -e

MODE="${1:-cloud}"
if [ "$MODE" != "cloud" ] && [ "$MODE" != "local" ]; then
  echo "Usage: $0 [cloud|local]"
  exit 1
fi

BACKEND_URL="http://192.168.0.116:4000/api"

DEVICE_ID=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')

if [ -z "$DEVICE_ID" ]; then
  echo "No device connected."
  echo "On your phone: Settings > Developer options > Wireless debugging > note the IP:port shown, then run:"
  echo "  adb connect <ip:port>"
  echo "...then run this script again."
  exit 1
fi

echo "Using device: $DEVICE_ID  (mode: $MODE)"
cd "$(dirname "$0")"
flutter run -d "$DEVICE_ID" --debug --flavor "$MODE" \
  --dart-define=DATA_MODE="$MODE" --dart-define=API_BASE_URL="$BACKEND_URL"
