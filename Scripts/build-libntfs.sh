#!/bin/bash
# Build a macOS libntfs-3g static archive for the FSKit extension.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Engine/ntfs-3g"
OUTPUT="$ROOT/build/libntfs-universal"
UNIVERSAL="${UNIVERSAL:-0}"

if [[ ! -f "$SOURCE/configure.ac" ]]; then
  echo "ntfs-3g sources missing; run Scripts/fetch-ntfs3g.sh first." >&2
  exit 1
fi

mkdir -p "$ROOT/_tmp"
WORK="$(mktemp -d "$ROOT/_tmp/libntfs-build.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/source"

rsync -a --exclude .git "$SOURCE/" "$WORK/source/"
mkdir -p "$WORK/source/m4"
cp "$ROOT/Scripts/ntfs3g/libgcrypt.m4" "$WORK/source/m4/libgcrypt.m4"
test -f "$WORK/source/configure.ac" || { echo "configure.ac missing after copy"; exit 1; }

(
  cd "$WORK/source"
  if [[ -x ./autogen.sh ]]; then
    ./autogen.sh
  else
    glibtoolize --force --copy --install
    LIBTOOLIZE=glibtoolize autoreconf -fi -I m4
  fi
)

SDK="$(xcrun --sdk macosx --show-sdk-path)"
BUILD_TRIPLET="$("$WORK/source/config.guess")"
NATIVE_ARCH="$(uname -m)"
if [[ "$NATIVE_ARCH" == aarch64 ]]; then
  NATIVE_ARCH=arm64
fi

if [[ "$UNIVERSAL" == "1" ]]; then
  ARCHS=(arm64 x86_64)
else
  ARCHS=("$NATIVE_ARCH")
fi

BUILT_LIBS=()
for ARCH in "${ARCHS[@]}"; do
  case "$ARCH" in
    arm64) HOST_TRIPLET=aarch64-apple-darwin ;;
    x86_64) HOST_TRIPLET=x86_64-apple-darwin ;;
    *) echo "unsupported arch $ARCH" >&2; exit 1 ;;
  esac
  CONFIGURE_CACHE=(CC=clang)
  if [[ "$ARCH" == "$NATIVE_ARCH" ]]; then
    HOST_TRIPLET="$BUILD_TRIPLET"
  else
    CONFIGURE_CACHE+=(
      ac_cv_func_memcmp_working=yes
      ac_cv_func_lstat_dereferences_slashed_symlink=yes
      ac_cv_func_stat_empty_string_bug=no
    )
  fi
  mkdir -p "$WORK/$ARCH"
  (
    cd "$WORK/$ARCH"
    env "${CONFIGURE_CACHE[@]}" \
      CFLAGS="-arch $ARCH -isysroot $SDK -mmacosx-version-min=26.0 -O2" \
      "$WORK/source/configure" \
        --build="$BUILD_TRIPLET" --host="$HOST_TRIPLET" \
        --disable-shared --enable-static \
        --disable-ntfs-3g --disable-ntfsprogs --disable-crypto --disable-nls
    make -C libntfs-3g -j"$(sysctl -n hw.ncpu)"
  )
  BUILT_LIBS+=("$WORK/$ARCH/libntfs-3g/.libs/libntfs-3g.a")
done

mkdir -p "$OUTPUT"
if [[ ${#BUILT_LIBS[@]} -eq 1 ]]; then
  cp "${BUILT_LIBS[0]}" "$OUTPUT/libntfs-3g.a"
  cp "$WORK/${ARCHS[0]}/config.h" "$OUTPUT/config.h"
else
  if ! cmp -s "$WORK/arm64/config.h" "$WORK/x86_64/config.h"; then
    echo 'Architectures produced different config.h; refusing to publish one shared header.' >&2
    diff -u "$WORK/arm64/config.h" "$WORK/x86_64/config.h" >&2 || true
    exit 1
  fi
  lipo -create "${BUILT_LIBS[@]}" -output "$OUTPUT/libntfs-3g.a"
  cp "$WORK/arm64/config.h" "$OUTPUT/config.h"
fi


# Publish public headers next to the static library for the Xcode target.
mkdir -p "$OUTPUT/include"
rsync -a "$SOURCE/include/" "$OUTPUT/include/"

echo "Built: $OUTPUT/libntfs-3g.a ($(lipo -archs "$OUTPUT/libntfs-3g.a" 2>/dev/null || echo native))"
