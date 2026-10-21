#!/usr/bin/env bash
# Build a custom OpenWrt image (any supported device) on the official
# Attended SysUpgrade (ASU) build server -- the same backend as
# firmware-selector.openwrt.org. Runs anywhere with bash+curl+jq (incl. aarch64
# Debian under proot), no local ImageBuilder needed.
#
# Usage:  ./build-asu.sh                 # 25.12.5, packages from packages.txt
#         VERSION=25.12.6 ./build-asu.sh
#         DEFAULTS=first-boot.sh ./build-asu.sh   # optional uci-defaults script
#
# NOTE: anything in DEFAULTS is uploaded to and stored on the public build
# server. Keep secrets (Wi-Fi keys, auth keys) out of it -- apply them over SSH
# after flashing with roaming-setup.sh instead.
set -euo pipefail

VERSION="${VERSION:-25.12.5}"
TARGET="${TARGET:?set TARGET, e.g. mediatek/filogic (see firmware-selector.openwrt.org)}"
PROFILE="${PROFILE:?set PROFILE, the device profile name from firmware-selector}"
ASU="${ASU:-https://sysupgrade.openwrt.org}"
PKG_FILE="${PKG_FILE:-$(dirname "$0")/packages.txt}"
OUT="${OUT:-./out/${VERSION}}"
DEFAULTS="${DEFAULTS:-}"

for b in curl jq sha256sum; do command -v "$b" >/dev/null || { echo "missing: $b" >&2; exit 1; }; done

pkgs_json=$(grep -vE '^\s*(#|$)' "$PKG_FILE" | awk '{print $1}' | jq -R . | jq -s .)

payload=$(jq -n \
  --arg v "$VERSION" --arg t "$TARGET" --arg p "$PROFILE" \
  --argjson pk "$pkgs_json" \
  --arg d "$( [ -n "$DEFAULTS" ] && cat "$DEFAULTS" || true )" \
  '{distro:"openwrt", version:$v, target:$t, profile:$p, packages:$pk,
    diff_packages:false, client:"roamer-build-asu/1.0"}
   + (if $d != "" then {defaults:$d} else {} end)')

if [ "${DRY_RUN:-0}" = 1 ]; then echo "$payload" | jq .; exit 0; fi

echo ">> Requesting $PROFILE $VERSION ($TARGET) with $(echo "$pkgs_json" | jq length) package changes"
resp=$(curl -sS -X POST -H 'Content-Type: application/json' -d "$payload" \
       -w '\n%{http_code}' "$ASU/api/v1/build")
code=$(tail -n1 <<<"$resp"); body=$(sed '$d' <<<"$resp")

hash=$(jq -r '.request_hash // empty' <<<"$body")
[ -n "$hash" ] || { echo "Build request rejected (HTTP $code):"; jq . <<<"$body" 2>/dev/null || echo "$body"; exit 1; }

while [ "$code" = 202 ]; do
  printf '   %s (queue %s)\r' "$(jq -r .detail <<<"$body")" "$(jq -r '.queue_position // 0' <<<"$body")"
  sleep 5
  resp=$(curl -sS -w '\n%{http_code}' "$ASU/api/v1/build/$hash")
  code=$(tail -n1 <<<"$resp"); body=$(sed '$d' <<<"$resp")
done
echo

if [ "$code" != 200 ]; then
  echo "Build failed (HTTP $code): $(jq -r .detail <<<"$body")"
  jq -r '.stderr // empty' <<<"$body" | tail -40
  exit 1
fi

bin_dir=$(jq -r .bin_dir <<<"$body")
mkdir -p "$OUT"
echo "$body" | jq . > "$OUT/build-response.json"
jq -r '.manifest // {} | to_entries[] | "\(.key) \(.value)"' <<<"$body" > "$OUT/manifest.txt"

jq -r '.images[] | select(.type=="factory" or .type=="sysupgrade") | "\(.name) \(.sha256)"' <<<"$body" |
while read -r name sum; do
  echo ">> $name"
  curl -sS -fL -o "$OUT/$name" "$ASU/store/$bin_dir/$name"
  echo "$sum  $OUT/$name" | sha256sum -c -
done

echo
echo "Done. Images in $OUT:"
ls -l "$OUT"
grep -E '^(tailscale|luci-app-tailscale-community|wpad-mbedtls|usteer|kernel) ' "$OUT/manifest.txt" || true
