#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/macos-app"
APP_BUNDLE="$APP_DIR/dist/Young Transcribe.app"
DMG_PATH="$APP_DIR/dist/Young-Transcribe.dmg"
SIGNED_DMG_PATH="$APP_DIR/dist/Young-Transcribe-signed.dmg"

: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE to a stored notarytool profile name}"

"$ROOT_DIR/scripts/build_macos_app.sh"

echo "Notarizing app..."
"$ROOT_DIR/scripts/notarize_macos_app.sh"

echo "Building DMG..."
"$ROOT_DIR/scripts/create_macos_dmg.sh"

if [[ -f "$SIGNED_DMG_PATH" ]]; then
  echo "Final release artifact:"
  echo "$SIGNED_DMG_PATH"
else
  echo "Final release artifact:"
  echo "$DMG_PATH"
fi
