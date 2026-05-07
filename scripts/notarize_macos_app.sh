#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/macos-app"
APP_BUNDLE="$APP_DIR/dist/Young Transcribe.app"
ZIP_PATH="$APP_DIR/dist/Young-Transcribe-notarization.zip"

: "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE to a stored notarytool profile name}"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Submitting for notarization..."
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
  --wait

echo "Stapling ticket..."
xcrun stapler staple "$APP_BUNDLE"

echo "Validating stapled app..."
spctl -a -vv "$APP_BUNDLE"

echo "Notarized app ready:"
echo "$APP_BUNDLE"
