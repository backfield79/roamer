#!/usr/bin/env bash
# Local build with the official OpenWrt ImageBuilder container.
# Requires an x86_64 host with Docker or Podman (ImageBuilder binaries are
# x86_64-only, so this will NOT run under aarch64 proot -- use build-asu.sh there).
#
# Usage:  ./build-imagebuilder.sh
#         VERSION=25.12.5 ENGINE=podman ./build-imagebuilder.sh
#         FILES_DIR=./files ./build-imagebuilder.sh   # overlay baked into rootfs
#
# Unlike the ASU path, FILES_DIR never leaves your machine, so baking
# /etc/config/* or /etc/uci-defaults/* with secrets in it is acceptable here.
set -euo pipefail

VERSION="${VERSION:-25.12.5}"
TARGET="${TARGET:?set TARGET, e.g. mediatek/filogic}"
PROFILE="${PROFILE:?set PROFILE (device profile name)}"
PLATFORM="$(echo "$TARGET" | tr / -)"
ENGINE="${ENGINE:-docker}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PKG_FILE="${PKG_FILE:-$HERE/packages.txt}"
WORK="${WORK:-$HERE/ib-$PLATFORM-$VERSION}"
FILES_DIR="${FILES_DIR:-}"

[ "$(uname -m)" = x86_64 ] || { echo "ImageBuilder needs x86_64; use build-asu.sh" >&2; exit 1; }

PACKAGES=$(grep -vE '^\s*(#|$)' "$PKG_FILE" | awk '{print $1}' | tr '\n' ' ')
mkdir -p "$WORK"/{bin,dl}

vols=(--volume "$WORK/bin:/builder/bin" --volume "$WORK/dl:/builder/dl")
files_arg=""
if [ -n "$FILES_DIR" ]; then
  vols+=(--volume "$(cd "$FILES_DIR" && pwd):/builder/files:ro")
  files_arg="FILES=/builder/files"
fi
userns=(); [ "$ENGINE" = podman ] && userns=(--userns=keep-id)

"$ENGINE" run --rm "${userns[@]}" "${vols[@]}" \
  "openwrt/imagebuilder:${PLATFORM}-${VERSION}" \
  sh -c "[ -d ./scripts ] || ./setup.sh; \
         make image PROFILE='$PROFILE' PACKAGES='$PACKAGES' $files_arg"

out="$WORK/bin/targets/$TARGET"
echo
ls -l "$out"/*"$PROFILE"* 2>/dev/null
( cd "$out" && sha256sum -- *"$PROFILE"* )
