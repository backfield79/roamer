## What and why

<!-- One or two sentences. Link the issue if there is one. -->

## Checklist

- [ ] `shellcheck -s sh roaming-setup.sh` is clean
- [ ] `sh tests/run.sh` passes (needs docker or podman)
- [ ] Tested on real hardware — models + OpenWrt release:
- [ ] Router-side code stays POSIX / busybox ash (no bash-isms, no non-default packages)
- [ ] Anything that changes the router has a backup, a rollback and a confirmation path
- [ ] README / docs / CHANGELOG updated if behaviour changed
