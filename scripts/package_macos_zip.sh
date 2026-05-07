#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/macos-app"
APP_BUNDLE="$APP_DIR/dist/Young Transcribe.app"
ZIP_PATH="$APP_DIR/dist/Young-Transcribe.zip"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Packaged zip:"
echo "$ZIP_PATH"
