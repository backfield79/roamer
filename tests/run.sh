#!/bin/sh
# Roamer test suite. Uses stand-ins for OpenWrt tools (tests/mock/bin) and a fake UCI database.
# It writes to /etc, /bin and /tmp, so it runs inside a throwaway container:
#   tests/run.sh              → starts an Alpine container (docker or podman) and runs there
#   ROAMER_IN_CONTAINER=1 tests/run.sh   → run here (only inside a disposable container/VM!)
set -u
T="$(cd "$(dirname "$0")" && pwd)"
if [ "${ROAMER_IN_CONTAINER:-0}" != 1 ]; then
  eng="$(command -v docker || command -v podman || true)"
  [ -n "$eng" ] || { echo "need docker or podman (or ROAMER_IN_CONTAINER=1 inside a disposable box)"; exit 2; }
  exec "$eng" run --rm -v "$T/..:/src:ro" -w /src alpine:3.20 sh -c \
    'apk add -q python3 util-linux-misc >/dev/null && cp -r /src /work && cd /work && ROAMER_IN_CONTAINER=1 sh tests/run.sh'
fi
. "$T/lib.sh"
GWJSON='{"up":true,"l3_device":"wan","ipv4-address":[{"address":"192.168.2.10","mask":24}],"route":[{"target":"0.0.0.0","nexthop":"192.168.2.1"}]}'
WIFI="TAILSCALE=no IFACE_2G=default_radio0 IFACE_5G=default_radio1 CH2=auto CH5=auto TXP2=keep TXP5=keep"

echo "== help"
fixture
run help "" help RS_MODE=ws
has help "Commands" "help screen lists the commands"

echo "== Gateway, from the computer (home menu → setup)"
fixture lanip=192.168.2.1 hostname=gateway
# welcome · menu=setup · backup · [router] device · mobility domain · plan
# shellcheck disable=SC2086
run gw '\n\n\n\n\ny\n' "" RS_MODE=ws ROUTER=192.168.2.1 ROLE=gateway BANDS=both COUNTRY=NL $WIFI \
  SSID=MyHome KEY=homepass1 ENC=sae-mixed HIDDEN=0 ROAM_DBM=-70 MOCK_BRIP=192.168.2.1/24
has gw "What do you want to do?" "home menu shown"
has gw "Mobility domain" "mobility-domain screen"
has gw "Don't" "mobility-domain do's and don'ts"
has gw "Gateway is set up successfully" "Gateway set up"
has gw "What is set up on 192.168.2.1" "report screen"
exists "$MOCK_STATE/ws/roamer-data/Gateway_gateway/pairing.txt" "pairing code saved in roamer-data/Gateway_<host>/"
exists "$MOCK_STATE/ws/roamer-data/Gateway_gateway/backups/*_192.168.2.1_backup.tar.gz" "backup in backups/"
exists "$MOCK_STATE/ws/roamer-data/Gateway_gateway/logs/*.ok.log" "log in logs/ as .ok.log"
if ls -d "$MOCK_STATE/ws/roamer-data"/Router_* >/dev/null 2>&1; then nok "pre-run folder merged into Gateway_<host>"; else ok "pre-run folder merged into Gateway_<host>"; fi
if grep -q "ROAM1:[A-Za-z0-9]" "$MOCK_STATE/ws/roamer-data"/Gateway_gateway/logs/*.ok.log; then nok "pairing code hidden in the log"; else ok "pairing code hidden in the log"; fi
if [ -e /tmp/roaming-env ]; then nok "presets file removed after use"; else ok "presets file removed after use"; fi
uci_is wireless.default_radio1.ieee80211r 1 "802.11r on"
cp "$MOCK_STATE/ws/roamer-data/Gateway_gateway/pairing.txt" /tmp/pair.keep 2>/dev/null || true
PAIRCODE="$(cat /tmp/pair.keep 2>/dev/null || true)"

echo "== Dumb AP, Gateway cable in WAN (temporary WAN path, cable move)"
fixture lanip=192.168.1.1 hostname=ap1
# welcome · menu · backup · [router] device · wiring · plan
# shellcheck disable=SC2086
run apwan '\n\n\n\n\ny\n' "" RS_MODE=ws ROUTER=192.168.2.10 PAIR="$PAIRCODE" WAN_JSON="$GWJSON" $WIFI \
  MOCK_WANIP=192.168.2.10/24 MOCK_BRIP=192.168.2.2/24 MOCK_PING_OK=192.168.2.10 MOCK_PING_AFTER=192.168.2.1 \
  MOCK_LATE_IP=192.168.2.2 MOCK_LATE_N=3 SSH_CLIENT="192.168.2.3 1 22" MOCK_ROUTE="192.168.2.3 dev wan" \
  NAME=ap1 AP_ADDR=static AP_IP=192.168.2.2 CONFIRM_TIMEOUT=120
has apwan "until you do, this router stays reachable at its current WAN address 192.168.2.10" "wiring check: Gateway on WAN"
has apwan "WAN keeps its lease (192.168.2.10)" "plan: temporary WAN path"
has apwan "Dumb AP is set up successfully" "Dumb AP confirmed and set up"
exists "$MOCK_STATE/ws/roamer-data/DumbAP_ap1/recovery/*_RECOVERY.txt" "recovery card in DumbAP_<host>/recovery/"
file_has "$MOCK_STATE/ws/roamer-data/hosts.txt" "192.168.2.2 ap1 fe80::" "Dumb AP remembered in hosts.txt"
file_has /tmp/roaming-apply.log "the Gateway answers through the LAN ports" "confirmed only via the LAN path"
file_has /tmp/roaming-apply.log "temporary WAN path removed" "temporary WAN path removed after confirmation"
uci_is network.wan '<unset>' "wan interface gone"
uci_is network.mgmt.ipaddr 192.168.1.2 "recovery address set"
uci_is dhcp.lan.ignore 1 "own DHCP off"

echo "== Dumb AP with WAN bridged into the LAN (the v4 leftover)"
WANCARRIER=1 fixture lanip=192.168.2.2 wanbr=1 hostname=obsidian
# shellcheck disable=SC2086
run apbr '\n\n\n\n\ny\n' "" RS_MODE=ws ROUTER=192.168.2.2 PAIR="$PAIRCODE" $WIFI MOCK_BRIP=192.168.2.2/24 \
  MOCK_GWLAN="192.168.2.1|192.168.2.157|24" MOCK_PING_OK=192.168.2.1 SSH_CLIENT="192.168.2.3 1 22" \
  NAME=obsidian AP_ADDR=static AP_IP=192.168.2.2 CONFIRM_TIMEOUT=120
has apbr "WAN port is bridged into its LAN" "wiring check spots the bridged WAN"
has apbr "WAN port: taken OUT of the LAN bridge" "plan removes it"
has apbr "Dumb AP is set up successfully" "set up"
uci_is network.cfg030f15.ports "lan1 lan2 lan3 lan4" "WAN no longer in br-lan"

echo "== lantest: laptop on a LAN port of a Dumb AP with bridged WAN"
WANCARRIER=1 fixture lanip=192.168.2.2 wanbr=1 hostname=obsidian
# check pause · measure pause · backup · apply
run lt '\n\n\n\n\n' lantest RS_MODE=ws AP_IP=192.168.2.2 GW_IP=192.168.2.1 MOCK_DOWN=192.168.2.2 \
  MOCK_FIXED_IP=192.168.2.2 MOCK_PING_OK=192.168.2.1 MOCK_BRIP=192.168.2.2/24
has lt "Found it" "names the cause"
has lt "backup saved" "backup before the change"
has lt "The Dumb AP answers on this cable now" "fixed and confirmed"
uci_is network.cfg030f15.ports "lan1 lan2 lan3 lan4" "WAN taken out of br-lan"
exists "$MOCK_STATE/ws/roamer-data/DumbAP_obsidian/backups/*_backup.tar.gz" "lantest backup in DumbAP_<host>/backups/"
exists "$MOCK_STATE/ws/roamer-data/DumbAP_obsidian/lantest/*.txt" "lantest report in DumbAP_<host>/lantest/"

echo "== the router's own current address is not 'in use'"
fixture lanip=192.168.2.10
# shellcheck disable=SC2086
run own '\n\n\n\n\n192.168.2.10\n' "" RS_MODE=ws ROUTER=192.168.2.10 PAIR="$PAIRCODE" $WIFI DRY_RUN=1 \
  MOCK_BRIP=192.168.2.10/24 MOCK_GWLAN="192.168.2.1|192.168.2.10|24" MOCK_PING_OK="192.168.2.10 192.168.2.50" \
  NAME=ap2 AP_ADDR=static
has own "192.168.2.10 is this router's current address" "own address accepted"
hasnt own "already in use by another device" "no false conflict"

echo "== run on the router itself: home menu → report"
fixture lanip=192.168.1.1
run rmenu '\n2\n' "" RS_MODE=router
has rmenu "Report — what is set up here" "router home menu"
has rmenu "role|Gateway" "report printed"

echo "== basic wpad on the router: swapped for the full one (apk 'provides' must not fool the check)"
WPAD=wpad-basic-mbedtls fixture lanip=192.168.2.1 hostname=gw2
# welcome · menu · backup · [router] device · install bundle y · pause · mobility domain · plan
# shellcheck disable=SC2086
run wpad '\n\n\n\ny\n\n\ny\n' "" RS_MODE=ws ROUTER=192.168.2.1 ROLE=gateway BANDS=both COUNTRY=NL $WIFI \
  SSID=MyHome KEY=homepass1 ENC=sae-mixed HIDDEN=0 ROAM_DBM=-70 MOCK_BRIP=192.168.2.1/24
has wpad "wpad-mbedtls  (full hostapd, replaces wpad-basic-mbedtls)" "basic wpad detected as not full"
file_has "$MOCK_STATE/apk.installed" "wpad-mbedtls" "full wpad installed"
if grep -qx wpad-basic-mbedtls "$MOCK_STATE/apk.installed"; then nok "basic wpad removed"; else ok "basic wpad removed"; fi
uci_is wireless.default_radio1.bss_transition 1 "802.11v on with the full wpad"
has wpad "Gateway is set up successfully" "set up"

echo "== Wi-Fi refuses to start → the Gateway rolls its Wi-Fi back"
fixture lanip=192.168.2.1 hostname=gw3
# shellcheck disable=SC2086
run wifail '\n\n\n\n\ny\n' "" RS_MODE=ws ROUTER=192.168.2.1 ROLE=gateway BANDS=both COUNTRY=NL $WIFI \
  SSID=MyHome KEY=homepass1 ENC=sae-mixed HIDDEN=0 ROAM_DBM=-70 MOCK_BRIP=192.168.2.1/24 MOCK_WIFI_FAIL=1 WIFI_WAIT=6
has wifail "Wi-Fi did not start" "Wi-Fi failure detected"
has wifail "ROLLED BACK: Wi-Fi settings restored" "Wi-Fi rolled back"
hasnt wifail "Gateway is set up successfully" "no false success"

echo "== hostapd refuses 802.11v (stale/basic build) → retried without it, not rolled back"
fixture lanip=192.168.2.1 hostname=gw4
# shellcheck disable=SC2086
run nownm '\n\n\n\n\ny\n' "" RS_MODE=ws ROUTER=192.168.2.1 ROLE=gateway BANDS=both COUNTRY=NL $WIFI \
  SSID=MyHome KEY=homepass1 ENC=sae-mixed HIDDEN=0 ROAM_DBM=-70 MOCK_BRIP=192.168.2.1/24 MOCK_WIFI_NOWNM=1 WIFI_WAIT=6
has nownm "retrying without it" "bss_transition refusal recognised"
has nownm "Gateway is set up successfully" "set up anyway"
has nownm "802.11v is off" "user told 802.11v is off and why"
uci_is wireless.default_radio1.bss_transition '<unset>' "bss_transition removed (=0 is still refused by such a hostapd)"
has nownm "unknown configuration item 'bss_transition'" "hostapd's own reason shown"

echo
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" = 0 ]
