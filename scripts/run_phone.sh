#!/bin/bash
# Builds and installs the app on the phone connected over wireless adb,
# pointed at the backend running on this Mac. Both the Mac's LAN IP and the
# phone's wireless-adb address are auto-detected on every run instead of
# hardcoded, since the debugging port in particular changes often (a new
# port shows up under Settings -> Developer options -> Wireless debugging
# most times it's re-enabled). Invoke via `make run` from frontend/, not
# this script directly, so the short command stays the one source of truth.
set -e

cd "$(dirname "$0")/.."

LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
if [ -z "$LAN_IP" ]; then
  echo "Could not detect this Mac's LAN IP (checked en0/en1). Are you connected to wifi?"
  exit 1
fi

PHONE=$(adb devices | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+[[:space:]]+device$/ {print $1; exit}')
if [ -z "$PHONE" ]; then
  echo "No phone connected over wireless adb."
  echo "On your phone: Settings -> Developer options -> Wireless debugging -> note the IP:port shown."
  echo "Then run: adb connect <ip:port>"
  exit 1
fi

BACKEND_URL="http://$LAN_IP:4000/api"
if ! curl -sf --max-time 2 "http://$LAN_IP:4000/health" > /dev/null; then
  echo "Warning: backend not responding at http://$LAN_IP:4000/health — start it first (cd ../backend && npm start)."
fi

echo "Phone: $PHONE"
echo "Backend: $BACKEND_URL"
flutter run -d "$PHONE" --dart-define=API_BASE_URL="$BACKEND_URL"
