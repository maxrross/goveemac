#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
CONFIG="debug"
UNIVERSAL=false
for option in "$@"; do
  case "$option" in
    --release) CONFIG="release" ;;
    --universal) UNIVERSAL=true ;;
    *) echo "Usage: $0 [--release] [--universal]" >&2; exit 2 ;;
  esac
done

APP_BUNDLE="$ROOT_DIR/dist/Govee Mac.app"
mkdir -p "$ROOT_DIR/dist"
if "$UNIVERSAL"; then
  swift build -c "$CONFIG" --triple arm64-apple-macosx14.0 --scratch-path .build/arm64
  swift build -c "$CONFIG" --triple x86_64-apple-macosx14.0 --scratch-path .build/x86_64
  ARM_BIN="$(swift build -c "$CONFIG" --triple arm64-apple-macosx14.0 --scratch-path .build/arm64 --show-bin-path)/GoveeMac"
  INTEL_BIN="$(swift build -c "$CONFIG" --triple x86_64-apple-macosx14.0 --scratch-path .build/x86_64 --show-bin-path)/GoveeMac"
  lipo -create "$ARM_BIN" "$INTEL_BIN" -output "$ROOT_DIR/dist/GoveeMac-universal"
  BUILD_BINARY="$ROOT_DIR/dist/GoveeMac-universal"
else
  swift build -c "$CONFIG"
  BUILD_BINARY="$(swift build -c "$CONFIG" --show-bin-path)/GoveeMac"
fi

# Only the generated bundle in this project's ignored dist/ directory is replaced.
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/GoveeMac"
chmod +x "$APP_BUNDLE/Contents/MacOS/GoveeMac"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT_DIR/Resources/GoveeMac.icns" "$APP_BUNDLE/Contents/Resources/GoveeMac.icns"
cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$APP_BUNDLE/Contents/Resources/"
# An existing development identity keeps Bluetooth permission stable locally.
SIGNING_IDENTITY="${GOVEE_MAC_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" && -f "$ROOT_DIR/.local-signing-identity" ]]; then
  IFS= read -r SIGNING_IDENTITY < "$ROOT_DIR/.local-signing-identity" || true
fi
codesign --force --sign "${SIGNING_IDENTITY:--}" "$APP_BUNDLE"
echo "Built $APP_BUNDLE"
