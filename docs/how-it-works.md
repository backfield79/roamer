# How it works

## Roles

| | Gateway | Dumb AP |
|---|---|---|
| What it is | your main router: WAN, DHCP, firewall, NAT | an extra router that becomes a switch + Wi-Fi in the Gateway's LAN |
| What Roamer changes | Wi-Fi, usteer, hostname | Wi-Fi, usteer, hostname, LAN address, DHCP server off, firewall off, WAN removed |
| Rollback | if internet is lost after applying | unless confirmed within 300 s |

Set up the Gateway first. It prints a **pairing code** (`ROAM1:…`, saved as
`roaming-pair_<gateway>.txt`), which carries SSID, password, encryption, mobility domain, country,
roaming threshold, the Gateway's address, its channels and its DHCP pool to every Dumb AP run.
It contains the Wi-Fi password, so keep it private.

## The steps

| Step | Gateway | Dumb AP |
|---|---|---|
| **This router**: model, board, CPU, arch/target, release, RAM, flash, radios, LAN ports | ✓ | ✓ |
| **Backup** into your folder | ✓ | ✓ |
| Role / pairing code | ✓ | ✓ |
| **Wiring check**: measured, see [wiring](wiring.md) | | ✓ |
| **Packages**: roaming bundle (required), Tailscale bundle (optional) | ✓ | ✓ |
| Bands · country · per radio: Wi-Fi network, channel, transmit power | ✓ | ✓ |
| SSID · password (typed twice) · encryption · visibility · mobility domain · roaming threshold | ✓ | from the code |
| Hostname · Gateway address · static/DHCP address | | ✓ |
| **Plan**: applied only after you answer `y` | ✓ | ✓ |
| Report | ✓ | ✓ |

Enter always takes the marked default (`← Enter`) and keeps current values. Wrong input is asked
again. `DRY_RUN=1` shows the plan and the exact UCI changes without writing anything.

## What a Dumb AP switch-over does

1. Stops its DHCP/RA server and firewall, restarts the network. The LAN links drop briefly, so
   wired clients ask the Gateway for a fresh address.
2. **WAN never stays in the LAN bridge.** On routers whose WAN and LAN ports reach the processor
   over different internal links (e.g. `wan@eth0`, `lan1@eth1`), a bridged WAN lets the router
   forward traffic but loses its *own* replies to LAN-port devices. Roamer removes such a bridge,
   also one left behind by an older run, and tells you to move the Gateway cable to a LAN port.
3. If the Gateway cable starts in WAN, the WAN lease stays up as a temporary way in until the
   Dumb AP is confirmed.
4. Self-check: every LAN port is in the bridge and the new address is present. A port without a
   cable is fine.
5. **Confirmation** = the Gateway answers through the LAN ports **and** someone logs in on the new
   address (the computer does it over a fresh connection, so it proves the new path). Otherwise:
   rollback, which never clashes with the Gateway's address and turns its DHCP back on once the
   Gateway cable is gone.
6. It also gets a **recovery address** (`192.168.1.<n>`, see [wiring](wiring.md)) and keeps its
   IPv6 link-local address, so a laptop cabled straight to it always gets in.

## Channels

`auto` lets hostapd pick at start-up from a restricted list: the Gateway uses 1/6/11 and 36–48; a
Dumb AP uses the 2.4 GHz channels the Gateway is not on, and 100–112 on 5 GHz when the Gateway is
in 36–48 (DFS: a 60 s radar check after boot). Fixed, different channels per router roam most
predictably.

## Mobility domain: do's and don'ts

A 4-hex ID that groups routers for 802.11r. A client connected to one of them hands over to the
next in ~50 ms instead of doing a full reconnect.

| Do | Don't |
|---|---|
| use the **same ID** on the Gateway and every Dumb AP, with the same SSID, password and encryption | give routers different IDs: clients still connect, but reconnect slowly instead of roaming |
| **keep** the current ID when re-running (Enter) | reuse the ID for another SSID (e.g. a guest network); each SSID gets its own |
| **derive** it from the SSID when unsure: every router computes the same value | change it on one router only: a new ID means re-running Roamer on all routers |
| let the pairing code carry it | expect a new ID to fix a client that won't roam; tune the roaming threshold instead |

## Packages

| Bundle | Packages | |
|---|---|---|
| **Roaming** (required) | full `wpad-*` (replaces `wpad-basic-*`), `usteer`, `ucode`, `luci-app-usteer` with LuCI | installed after a warning; the run stops if you decline |
| **Tailscale** (optional) | `tailscale`, `luci-app-tailscale-community` with LuCI | installed only; **set it up yourself afterwards** |

A Dumb AP without internet on WAN borrows a temporary lease from the Gateway on its LAN for the
download.

## Files

| File (in the folder you run from, mode 600) | What |
|---|---|
| `roaming-setup_<host>_<ip>_<time>_backup.tar.gz` | full backup: `sysupgrade -r <file>; reboot` |
| `roaming-setup_<host>_<ip>_<time>_ok.log` / `_err.log` | session log |
| `roaming-setup_<host>_<ip>_<time>_RECOVERY.txt` | how to get a Dumb AP back |
| `roaming-pair_<gateway>.txt` | pairing code (contains the Wi-Fi password) |
| `roaming-hosts.txt` | each Dumb AP's address, hostname and IPv6 link-local |
| `roaming-lantest_<time>.txt` | LAN-port test results |

On the router: `/etc/roaming-setup.bak/<time>/` (snapshot, `restore.sh`, `RECOVERY.txt`) and
`/etc/roaming-setup.bak/restore-latest.sh`. The Wi-Fi password travels to the router in a temporary
0600 file, never on a command line.
