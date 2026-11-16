#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
  export PATH="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
fi
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/clang-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$ROOT_DIR/.build/swiftpm-cache}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
SHARE_DIR="$ROOT_DIR/dist/分享给朋友"
ARCHIVE_DIR="$ROOT_DIR/dist/archive"
mkdir -p "$SHARE_DIR" "$ARCHIVE_DIR"

build_app() {
  local arch="$1"
  local destination="$2"
  local app="$destination/喝水BO～.app"

  xcrun swift build --arch "$arch" -c release
  local build_dir
  build_dir="$(xcrun swift build --arch "$arch" -c release --show-bin-path)"

  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$build_dir/WaterReminder" "$app/Contents/MacOS/WaterReminder"
  cp Resources/Info.plist "$app/Contents/Info.plist"
  cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
  cp "Resources/喝水BO～.shortcut" "$app/Contents/Resources/喝水BO～.shortcut"
  cp "Resources/喝水BO～ 手表.shortcut" "$app/Contents/Resources/喝水BO～ 手表.shortcut"
  xattr -cr "$app"
  codesign --force --sign - "$app"
  codesign --verify --deep --strict "$app"
  lipo "$app/Contents/MacOS/WaterReminder" -verify_arch "$arch"
}

make_dmg() {
  local app="$1"
  local output="$2"
  local staging
  staging="$(mktemp -d)"
  trap 'rm -rf "$staging"' RETURN
  ditto "$app" "$staging/喝水BO～.app"
  ln -s /Applications "$staging/应用程序"
  rm -f "$output"
  hdiutil create -quiet -volname "喝水BO～ $VERSION" \
    -srcfolder "$staging" -ov -format UDZO "$output"
  rm -rf "$staging"
  trap - RETURN
}

build_app arm64 "$ROOT_DIR/dist/apple-silicon"
build_app x86_64 "$ROOT_DIR/dist/intel"

make_dmg "$ROOT_DIR/dist/apple-silicon/喝水BO～.app" \
  "$ROOT_DIR/dist/喝水BO～-AppleSilicon.dmg"
make_dmg "$ROOT_DIR/dist/intel/喝水BO～.app" \
  "$ROOT_DIR/dist/喝水BO～-Intel.dmg"

cp "$ROOT_DIR/dist/喝水BO～-AppleSilicon.dmg" "$SHARE_DIR/"
cp "$ROOT_DIR/dist/喝水BO～-Intel.dmg" "$SHARE_DIR/"
cp "docs/iphone-shortcut/喝水BO～.shortcut" \
  "$ROOT_DIR/dist/喝水BO～-iPhone-$VERSION.shortcut"
cp "docs/iphone-shortcut/喝水BO～ 手表.shortcut" \
  "$ROOT_DIR/dist/喝水BO～-Watch-$VERSION.shortcut"
cp "docs/iphone-shortcut/喝水BO～.shortcut" \
  "$SHARE_DIR/喝水BO～ $VERSION.shortcut"
cp "docs/iphone-shortcut/喝水BO～ 手表.shortcut" \
  "$SHARE_DIR/喝水BO～ 手表 $VERSION.shortcut"
cp "docs/安装与使用说明.txt" "$ROOT_DIR/dist/安装与使用说明.txt"
cp "docs/安装与使用说明.txt" "$SHARE_DIR/安装与使用说明.txt"
cp "docs/发给朋友.txt" "$SHARE_DIR/发给朋友.txt"

echo "Release $VERSION built in $ROOT_DIR/dist"
