#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/macos-app"
BUILD_DIR="$APP_DIR/.build/release"
APP_NAME="Young Transcribe.app"
APP_BUNDLE="$APP_DIR/dist/$APP_NAME"
EXECUTABLE_NAME="macos-app"
RESOURCE_BUNDLE_NAME="macos-app_macos-app.bundle"
ICON_SOURCE="$APP_DIR/AppAssets/app-icon-source.png"
ENTITLEMENTS_PATH="$APP_DIR/Transcribe.entitlements"
ICONSET_DIR="$APP_DIR/.build/AppIcon.iconset"
ICNS_PATH="$APP_DIR/.build/AppIcon.icns"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

mkdir -p "$APP_DIR/dist"
rm -rf "$APP_BUNDLE" "$ICONSET_DIR" "$ICNS_PATH"

cd "$APP_DIR"
swift build -c release

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$APP_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

RESOURCE_BUNDLE_PATH="$(find "$APP_DIR/.build" -name "$RESOURCE_BUNDLE_NAME" -type d | head -n 1)"
if [[ -n "$RESOURCE_BUNDLE_PATH" ]]; then
  cp -R "$RESOURCE_BUNDLE_PATH" "$APP_BUNDLE/Contents/Resources/"
fi

xattr -cr "$APP_BUNDLE"

mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
cp "$ICNS_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

xattr -cr "$APP_BUNDLE"
codesign \
  --force \
  --deep \
  --options runtime \
  --entitlements "$ENTITLEMENTS_PATH" \
  --sign "$SIGNING_IDENTITY" \
  "$APP_BUNDLE"

echo "Built app bundle:"
echo "$APP_BUNDLE"
