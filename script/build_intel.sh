#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
swift build --arch x86_64 -c release
BUILD_DIR="$(swift build --arch x86_64 -c release --show-bin-path)"
APP_BUNDLE="$ROOT_DIR/dist/intel/喝水BO～.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/WaterReminder" "$APP_BUNDLE/Contents/MacOS/WaterReminder"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
lipo "$APP_BUNDLE/Contents/MacOS/WaterReminder" -verify_arch x86_64
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ROOT_DIR/dist/喝水BO～-Intel.zip"
