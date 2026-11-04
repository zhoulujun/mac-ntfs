#!/bin/bash
# Fetch engine, build libntfs, generate Xcode project, and compile Debug.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

./Scripts/fetch-ntfs3g.sh
./Scripts/build-libntfs.sh
mkdir -p build/libntfs-universal/include
rsync -a Engine/ntfs-3g/include/ build/libntfs-universal/include/
command -v xcodegen >/dev/null || { echo "brew install xcodegen"; exit 1; }
xcodegen generate

xcodebuild -project mac-ntfs.xcodeproj -scheme MacNTFS -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project mac-ntfs.xcodeproj -target mac-ntfs-cli -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO build

echo "Build complete. Open mac-ntfs.xcodeproj, set your Team + FSKit entitlement, then install to /Applications."
