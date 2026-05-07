#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/macos-app"
APP_BUNDLE="$APP_DIR/dist/Young Transcribe.app"
DMG_DIR="$APP_DIR/dist/dmg"
STAGING_DIR="$DMG_DIR/staging"
DMG_PATH="$APP_DIR/dist/Young-Transcribe.dmg"
SIGNED_DMG_PATH="$APP_DIR/dist/Young-Transcribe-signed.dmg"
BACKGROUND_SOURCE="$APP_DIR/AppAssets/app-icon-source.png"
VOLUME_NAME="Young Transcribe"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

rm -rf "$DMG_DIR" "$DMG_PATH" "$SIGNED_DMG_PATH"
mkdir -p "$STAGING_DIR"

cp -R "$APP_BUNDLE" "$STAGING_DIR/"

ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "${SIGNING_IDENTITY:-}" && "$SIGNING_IDENTITY" != "-" ]]; then
  codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"
  cp "$DMG_PATH" "$SIGNED_DMG_PATH"
  xcrun notarytool submit "$SIGNED_DMG_PATH" \
    --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
    --wait
  xcrun stapler staple "$SIGNED_DMG_PATH"
  xcrun stapler validate "$SIGNED_DMG_PATH"
  echo "Signed and notarized DMG ready:"
  echo "$SIGNED_DMG_PATH"
else
  echo "Unsigned DMG ready:"
  echo "$DMG_PATH"
fi
