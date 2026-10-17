# Changelog

All notable changes. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow `VERSION` in `roaming-setup.sh`.

## [8.0] — 2026-10-17

First public release.

### Added
- **Home menu** on the computer and on the router: setup, lantest, report, state, status, diag,
  pair, confirm, undo, help. Every entry also works as a command (`./roaming-setup.sh lantest`).
- `undo`: restore the snapshot taken before the last run (on the router or from the computer).
- Test suite with OpenWrt stand-ins, run in an Alpine container under busybox ash; CI with
  ShellCheck.

### Changed
- Presets, including the Wi-Fi password, travel to the router in a temporary 0600 file instead of
  on the SSH command line (where `ps` could show them).
- The check for other uncommitted UCI changes runs before any package is installed.
- Unattended runs stop when the router can't be reached, instead of retrying forever.
- Pairing codes (they hold the Wi-Fi password) are hidden in log files.
- Confirmation deadlines on both sides are measured by the clock, not by counting sleeps (on a
  slow router the rollback used to come later than announced).

### Fixed
- Background probes no longer read keyboard input; `roaming-hosts.txt` lookups match exactly.

## [7.5] — 2026-10-17
### Fixed
- **Root cause of "a laptop on a Dumb AP's LAN port has internet but can't reach the Dumb AP"**:
  WAN was a member of the LAN bridge (bridged by v4 and never removed). On routers whose WAN and LAN
  ports use different CPU links, the router's own replies to LAN ports got lost. The switch-over now
  always takes WAN out of the bridge; the wiring check reports a bridged WAN.
- `lantest`: the Gateway login comes first and has no time limit (an 8 s timeout used to kill the
  password prompt); backup before any change; the reboot step verifies the reboot; a fix counts only
  after two ping rounds plus SSH.
### Added
- `lantest` detects a bridged WAN and fixes it with auto-revert and confirmation over the cable.

## [7.4]
### Added
- `lantest`; "go through the Gateway" when a router isn't reachable directly.
### Changed
- No more LAN-port leave/re-join ("bounce") during the switch-over.

## [7.3]
### Added
- IPv6 link-local access to a Dumb AP (found automatically); recovery address in static mode;
  `diag`; Tailscale accept-routes check; `roaming-hosts.txt`.
### Fixed
- Hostname is applied immediately; the board's LAN MAC is kept.

## [7.2]
### Fixed
- False confirmation through a shared SSH session to the old address; self-check failing while a
  cable was being moved; the router's own address reported as "in use".
### Added
- Temporary WAN path until confirmation; Report screen; mobility-domain do's and don'ts.

## [7.1]
### Added
- Progress bar with chapters; wiring diagnostics with retry; the computer confirms the Dumb AP.

## [7.0]
### Added
- Device info, package bundles, welcome screen, styled screens, measured wiring check; no
  device-specific code.

## [6.x] and earlier
- Interactive Gateway/Dumb AP setup, pairing code, backups, logs, recovery card, auto-rollback.
