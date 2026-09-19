#!/bin/bash
# Installs and runs the app on whichever device is currently connected over
# ADB (wireless or USB) — no need to know its IP:port, it auto-detects.
#
# BACKEND_URL below is the Mac's LAN IP running the backend (`node
# src/server.js` in ../backend). If the phone can't reach the backend after
# this runs, your Mac's IP may have changed — check it with:
#   ipconfig getifaddr en0
# and update BACKEND_URL below to match.

set -e

BACKEND_URL="http://192.168.0.116:4000/api"

DEVICE_ID=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')

if [ -z "$DEVICE_ID" ]; then
  echo "No device connected."
  echo "On your phone: Settings > Developer options > Wireless debugging > note the IP:port shown, then run:"
  echo "  adb connect <ip:port>"
  echo "...then run this script again."
  exit 1
fi

echo "Using device: $DEVICE_ID"
cd "$(dirname "$0")"
flutter run -d "$DEVICE_ID" --debug --dart-define=API_BASE_URL="$BACKEND_URL"
