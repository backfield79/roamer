#!/bin/sh
# Test helpers. These tests write to /etc, /bin and /tmp — run them only in a throwaway
# container (tests/run.sh does that for you).
T="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$T/.." && pwd)"; SCRIPT="$ROOT/roaming-setup.sh"
export MOCK_STATE=/tmp/roamer-mock
ESC="$(printf '\033')"; CR="$(printf '\r')"
PASS=0; FAIL=0

fixture() {   # fixture [mkdb options…] — a fresh fake OpenWrt router
  rm -rf "$MOCK_STATE" /etc/config /etc/roaming-setup.bak /etc/roaming-setup.pair /tmp/roaming-* /tmp/roamer-*
  mkdir -p "$MOCK_STATE/ws" "$MOCK_STATE/sys/br-lan/brif" "$MOCK_STATE/sys/wan" /etc/config /etc/init.d /tmp/sysinfo
  for p in lan1 lan2 lan3 lan4; do : > "$MOCK_STATE/sys/br-lan/brif/$p"; done
  echo down > "$MOCK_STATE/sys/br-lan/operstate"
  echo "${WANCARRIER:-0}" > "$MOCK_STATE/sys/wan/carrier"; echo aa:bb:cc:00:00:02 > "$MOCK_STATE/sys/wan/address"
  printf "DISTRIB_ID='OpenWrt'\nDISTRIB_DESCRIPTION='OpenWrt 25.12.5'\nDISTRIB_ARCH='arm_cortex-a15_neon-vfpv4'\nDISTRIB_TARGET='ipq806x/generic'\n" > /etc/openwrt_release
  echo '{"network":{"lan":{"ports":["lan1","lan2","lan3","lan4"]},"wan":{"device":"wan"}}}' > /etc/board.json
  for s in network firewall dnsmasq odhcpd usteer system; do
    printf '#!/bin/sh\ncase "$1" in enabled) [ %s != usteer ];; *) exit 0;; esac\n' "$s" > "/etc/init.d/$s"; chmod +x "/etc/init.d/$s"
  done
  for f in wireless system dhcp firewall network; do echo "# test" > "/etc/config/$f"; done
  echo "Test Router" > /tmp/sysinfo/model
  cp "$T/mock/bin/ipcalc.sh" /bin/ipcalc.sh
  printf '%s\nusteer\nucode\nluci-base\nluci-app-usteer\n' "${WPAD:-wpad-mbedtls}" > "$MOCK_STATE/apk.installed"
  python3 "$T/mock/mkdb.py" "$MOCK_STATE/live.json" "$@"
}

run() {   # run <name> <answers (printf format)> <script args> [VAR=value …]
  _n="$1" _a="$2" _arg="$3"; shift 3
  ( cd "$MOCK_STATE/ws" && { sleep 1; printf "$_a"; } | env "$@" SYSNET="$MOCK_STATE/sys" COLS=96 TERM=xterm \
      PATH="$T/mock/bin:$PATH" timeout "${RUN_TIMEOUT:-300}" script -qec "sh $SCRIPT $_arg" /dev/null > "$MOCK_STATE/$_n.raw" 2>&1 ) || true
  sed "s/${ESC}\[[0-9;]*[A-Za-z]//g; s/${CR}//g" "$MOCK_STATE/$_n.raw" > "$MOCK_STATE/$_n.txt"
}

ok()   { PASS=$((PASS+1)); echo "  ok    $*"; }
nok()  { FAIL=$((FAIL+1)); echo "  FAIL  $*"; }
has()  { if grep -qF -- "$2" "$MOCK_STATE/$1.txt"; then ok "$3"; else nok "$3 — missing: $2"; fi; }
hasnt(){ if grep -qF -- "$2" "$MOCK_STATE/$1.txt"; then nok "$3 — unexpected: $2"; else ok "$3"; fi; }
uci_is() { _v="$(python3 "$T/mock/bin/uci.py" -q get "$1" 2>/dev/null || echo '<unset>')"
           if [ "$_v" = "$2" ]; then ok "$3"; else nok "$3 — $1 is '$_v', expected '$2'"; fi; }
file_has() { if grep -qF -- "$2" "$1" 2>/dev/null; then ok "$3"; else nok "$3 — $1 lacks: $2"; fi; }
exists() { if ls $1 >/dev/null 2>&1; then ok "$2"; else nok "$2 — no $1"; fi; }
wait_job() { _i=0; while [ $_i -lt 100 ]; do grep -q "^${1}" /tmp/roaming-state 2>/dev/null && return 0; sleep 0.1 2>/dev/null; _i=$((_i+1)); done; }
