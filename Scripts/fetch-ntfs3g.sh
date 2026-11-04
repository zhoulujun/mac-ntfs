#!/bin/bash
# Fetch the ntfs-3g revision used by xntfs (supports --disable-ntfs-3g on Darwin).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Engine/ntfs-3g"
# Pin matches HuanchuanTech/xntfs submodule
PIN="${NTFS3G_PIN:-7f0f841fc52cf719106c5c93bafe465004e36816}"
mkdir -p "$ROOT/Engine"
if [[ -f "$DEST/configure.ac" ]] && grep -q 'disable-ntfs-3g' "$DEST/configure.ac"; then
  echo "ntfs-3g already present at $DEST"
  exit 0
fi
TMP="$(mktemp -t ntfs3g.XXXXXX.tar.gz)"
trap 'rm -f "$TMP"' EXIT
curl -L --retry 3 \
  "https://codeload.github.com/tuxera/ntfs-3g/tar.gz/${PIN}" \
  -o "$TMP"
rm -rf "$DEST"
tar -xzf "$TMP" -C "$ROOT/Engine"
mv "$ROOT/Engine/ntfs-3g-${PIN}" "$DEST" 2>/dev/null \
  || mv "$ROOT/Engine"/ntfs-3g-* "$DEST"
echo "Fetched ntfs-3g ${PIN} into $DEST"
