#!/bin/bash
# Archive, Developer ID sign, notarize, and wrap a DMG for distribution.
# Requires: Xcode, notarytool credentials, Developer ID Application cert.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TEAM_ID="${MACNTFS_TEAM_ID:?Set MACNTFS_TEAM_ID to your Apple Team ID}"
SIGN_ID="${MACNTFS_SIGN_IDENTITY:-Developer ID Application}"
BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :MARKETING_VERSION' project.yml 2>/dev/null || echo 0.1.0)"
# Prefer MARKETING_VERSION from project.yml settings
VERSION="${MACNTFS_VERSION:-0.1.0}"
OUT="$ROOT/build/dist"
APP_NAME="mac-ntfs"
SCHEME="MacNTFS"

./Scripts/fetch-ntfs3g.sh
./Scripts/build-libntfs.sh
command -v xcodegen >/dev/null || { echo "install xcodegen"; exit 1; }
xcodegen generate

mkdir -p "$OUT"
ARCHIVE="$OUT/$APP_NAME.xcarchive"
rm -rf "$ARCHIVE" "$OUT/$APP_NAME.app" "$OUT/$APP_NAME-$VERSION.dmg"

xcodebuild \
  -project mac-ntfs.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_ID" \
  archive

# Export locally signed app from archive
APP=$(find "$ARCHIVE/Products" -name '*.app' | head -1)
cp -R "$APP" "$OUT/$APP_NAME.app"

# Notarize (expects keychain profile MACNTFS_NOTARY_PROFILE or NOTARYTOOL_* env)
PROFILE="${MACNTFS_NOTARY_PROFILE:-mac-ntfs-notary}"
ditto -c -k --keepParent "$OUT/$APP_NAME.app" "$OUT/$APP_NAME.zip"
xcrun notarytool submit "$OUT/$APP_NAME.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$OUT/$APP_NAME.app"

# DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$OUT/$APP_NAME.app" -ov -format UDZO "$OUT/$APP_NAME-$VERSION.dmg"
echo "Built $OUT/$APP_NAME-$VERSION.dmg"
