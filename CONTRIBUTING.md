# Contributing

Thanks for helping. Roamer changes the network of real routers, so the bar is: **never leave a
router unreachable**.

## Reporting a problem

Open an issue with the template. Most useful: router models + OpenWrt release, the exact wiring,
the session log from your folder, and for a Dumb AP `./roaming-setup.sh status` / `diag` or the
`roaming-lantest_…txt`. **Remove Wi-Fi passwords and pairing codes** before posting.

## Code rules

- `roaming-setup.sh` is one POSIX shell script. The router side runs on **busybox ash** with only
  default OpenWrt packages (`uci`, `ubus`, `jsonfilter`, `ucode`, `iwinfo`, `udhcpc`); no bash-isms.
  The computer side may assume `ssh` and common Unix tools (Linux and macOS).
- Every change to a router needs a **backup**, a **rollback** and a **confirmation** path, and must
  be shown in the plan before it happens.
- Every prompt must be presettable by a variable, and wrong input must be asked again, never crash.
- Keep messages short and concrete; say what the user should do next.
- Secrets never go on a command line, into logs, or into public build requests.

## Before a pull request

```sh
shellcheck -s sh roaming-setup.sh
sh tests/run.sh          # needs docker or podman; runs the mocked scenarios under busybox ash
```

Add or extend a scenario in `tests/run.sh` for behaviour you change. The stand-ins for OpenWrt
tools live in `tests/mock/bin`. Test on real hardware when you touch networking, and say which.

Update `CHANGELOG.md` and the docs when behaviour changes, and bump `VERSION` in the script for a release.
