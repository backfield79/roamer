# Wiring

A finished Dumb AP is a switch + Wi-Fi with one fixed address in the Gateway's network and **no
DHCP server of its own**. Keep your computer on the Gateway whenever you can.

## Wirings that work

| Situation | Computer | Dumb AP cabling | Works |
|---|---|---|---|
| Gateway run | on the Gateway (LAN or Wi-Fi) | | ✓ |
| Dumb AP run, **recommended** | on the Gateway | Dumb AP **LAN** port ↔ Gateway LAN | ✓ |
| Dumb AP run, Gateway on its **WAN** | on the Gateway, router reached at its WAN address | Dumb AP WAN ↔ Gateway LAN | ✓ you move the cable to a LAN port at the switch-over; the WAN address keeps answering until confirmed |
| Computer on a Dumb AP LAN port | on a Dumb AP LAN port | Dumb AP LAN ↔ Gateway LAN | ✓ address via the Gateway |
| **First run on a new router** (192.168.1.1, its own DHCP) | **directly** on its LAN port | WAN → Gateway LAN is fine | ✓ once; then move the computer to the Gateway |
| Computer cabled **straight to a Dumb AP**, any settings | on any Dumb AP LAN port | Gateway connected or not | ✓ see below |
| Fresh router reached on its WAN address | on the Gateway | Dumb AP WAN ↔ Gateway LAN | ✗ its firewall blocks SSH on WAN; use the "first run" row |

**Exactly one cable** between a Dumb AP and the Gateway; two make a loop. Keep a way to cable a
laptop to the **first LAN port**, because OpenWrt failsafe answers only there.

## The wiring check (Dumb AP runs)

Roamer measures instead of assuming: whether the Gateway's DHCP answers on the LAN bridge, whether
WAN has a lease from the Gateway, whether WAN is (still) *inside* the LAN bridge, how your console
reaches the router, and whether the router's own DHCP server is active.

| Measured | Meaning |
|---|---|
| Gateway on a **LAN port** | final wiring already: nothing to recable |
| Gateway on **WAN** | fine; you move the cable at the switch-over |
| WAN **bridged into the LAN**, cable in it | left over from an older setup; Roamer removes the bridge and you move the cable |
| **not connected** | connect Gateway LAN → this router's WAN, re-check |

## A laptop cabled straight to a Dumb AP

| Way | Laptop | Command |
|---|---|---|
| **Automatic** | any settings | `./roaming-setup.sh`, type its usual address; when it doesn't answer, Roamer finds the router on the cable over IPv6 link-local and asks "Set up this router?" |
| **IPv6 link-local** | any settings | `ssh root@fe80::…%<interface>` (Linux `eth0`/`enp…`, macOS `en…`, Windows the interface number); the address is in the report and `roaming-hosts.txt` |
| **Recovery address** | fixed `192.168.1.10/24` (as for failsafe) | `ssh root@192.168.1.<n>`; `<n>` = last number of its LAN address (`192.168.254.<n>` if the Gateway itself uses 192.168.1.x) |
| **Through the Gateway** | address from the Gateway | `ssh -J root@<gateway> root@<dumb-ap>`, or "go through the Gateway" when Roamer can't reach a router |

If the laptop has internet on a Dumb AP's LAN port but the Dumb AP doesn't answer, run
`./roaming-setup.sh lantest`; see [troubleshooting](troubleshooting.md).
