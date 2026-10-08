#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: GOVEE_NOTARY_PROFILE=profile GOVEE_RELEASE_SIGNING_IDENTITY='Developer ID Application: …' $0 /path/to/Govee\ Mac.app [output-directory]"
}
if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 1 || $# -gt 2 ]]; then usage >&2; exit 2; fi
: "${GOVEE_NOTARY_PROFILE:?Set GOVEE_NOTARY_PROFILE to an existing notarytool keychain profile.}"
: "${GOVEE_RELEASE_SIGNING_IDENTITY:?Set GOVEE_RELEASE_SIGNING_IDENTITY to your Developer ID Application certificate.}"
case "$GOVEE_RELEASE_SIGNING_IDENTITY" in
  'Developer ID Application:'*) ;;
  *) echo "Use a Developer ID Application certificate for distribution." >&2; exit 2 ;;
esac

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_APP="$1"
OUTPUT_DIR="${2:-$PROJECT_DIR/dist}"
[[ -d "$INPUT_APP" ]] || { echo "App bundle not found: $INPUT_APP" >&2; exit 2; }
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INPUT_APP/Contents/Info.plist")"
[[ "$BUNDLE_ID" == "community.goveemac.app" ]] || { echo "Expected a Govee Mac app bundle." >&2; exit 2; }
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INPUT_APP/Contents/Info.plist")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Expected a three-part app version." >&2; exit 2; }
ARCHS="$(lipo "$INPUT_APP/Contents/MacOS/GoveeMac" -archs)"
[[ "$ARCHS" == "arm64 x86_64" || "$ARCHS" == "x86_64 arm64" ]] || { echo "Build a universal app first." >&2; exit 2; }

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/.govee-notary.XXXXXX")"
STAGED_APP="$STAGING_DIR/Govee Mac.app"
ditto "$INPUT_APP" "$STAGED_APP"
# The CLI is the only nested executable; frameworks need explicit support.
for folder in Frameworks XPCServices PlugIns; do
  if [[ -d "$STAGED_APP/Contents/$folder" ]]; then
    echo "Sign nested code explicitly before extending this workflow: $folder" >&2
    exit 2
  fi
done

# Validate the saved credentials without printing or placing secrets in the repo.
xcrun notarytool history --keychain-profile "$GOVEE_NOTARY_PROFILE" --output-format json > /dev/null
CLI="$STAGED_APP/Contents/MacOS/govee"
[[ -x "$CLI" ]] || { echo "Bundled CLI is missing." >&2; exit 2; }
CLI_ARCHS="$(lipo "$CLI" -archs)"
[[ "$CLI_ARCHS" == "arm64 x86_64" || "$CLI_ARCHS" == "x86_64 arm64" ]] || { echo "Build a universal CLI first." >&2; exit 2; }
codesign --force --sign "$GOVEE_RELEASE_SIGNING_IDENTITY" --identifier community.goveemac.cli --options runtime --timestamp "$CLI"
codesign --verify --strict "$CLI"
codesign --force --sign "$GOVEE_RELEASE_SIGNING_IDENTITY" --entitlements "$PROJECT_DIR/Resources/Entitlements.plist" --options runtime --timestamp "$STAGED_APP"
codesign --verify --strict "$STAGED_APP"
ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$STAGING_DIR/submission.zip"
echo "Notarization files are retained at $STAGING_DIR if processing fails or times out."
xcrun notarytool submit "$STAGING_DIR/submission.zip" --keychain-profile "$GOVEE_NOTARY_PROFILE" \
  --wait --timeout 15m --output-format json > "$STAGING_DIR/submission.json"
STATUS="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status", ""))' "$STAGING_DIR/submission.json")"
[[ "$STATUS" == "Accepted" ]] || { echo "Notarization status: $STATUS. Inspect the submission before publishing." >&2; exit 1; }
xcrun stapler staple "$STAGED_APP"
xcrun stapler validate "$STAGED_APP"
codesign --verify --strict "$STAGED_APP"
spctl --assess --type execute --verbose=2 "$STAGED_APP"

ARCHIVE="Govee-Mac-$VERSION-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$STAGED_APP" "$OUTPUT_DIR/$ARCHIVE"
cd "$OUTPUT_DIR"
shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt
echo "Ready to publish: $OUTPUT_DIR/$ARCHIVE"
