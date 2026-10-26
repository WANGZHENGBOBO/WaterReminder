#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
APP_BUNDLE="$ROOT_DIR/dist/喝水BO～.app"
case "$MODE" in run|--verify|--build-only|--debug|--logs|--telemetry) ;; *) exit 2 ;; esac
if [[ "$MODE" != "--build-only" ]]; then
  pkill -x WaterReminder >/dev/null 2>&1 || true
fi
swift build
BUILD_DIR="$(swift build --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/WaterReminder" "$APP_BUNDLE/Contents/MacOS/WaterReminder"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP_BUNDLE"
case "$MODE" in
  --build-only) exit 0 ;;
  --debug) exec lldb -- "$APP_BUNDLE/Contents/MacOS/WaterReminder" ;;
esac
/usr/bin/open -n "$APP_BUNDLE"
case "$MODE" in
  --verify) sleep 2; pgrep -x WaterReminder ;;
  --logs) /usr/bin/log stream --info --style compact --predicate 'process == "WaterReminder"' ;;
  --telemetry) /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.bobo.WaterReminder"' ;;
esac
