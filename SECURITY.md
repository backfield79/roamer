# Security policy

## Reporting

Please report vulnerabilities **privately** through GitHub's "Report a vulnerability" (Security tab),
not in a public issue. Include the Roamer version and steps to reproduce.

## What Roamer handles

- It logs in to your routers as `root` over SSH. Host keys are kept per run (`accept-new`); it never
  stores passwords.
- The **Wi-Fi password** is in the pairing code (`roaming-pair_*.txt`), in the router snapshot under
  `/etc/roaming-setup.bak/`, and in the backups. All files Roamer writes on your computer are mode
  600 and listed in `.gitignore`; don't commit or share them.
- The password reaches the router in a temporary 0600 file that is deleted after reading, never on a
  command line. It is masked in dry runs, and pairing codes are hidden in log files.
- On a Dumb AP the firewall is turned off (it is a bridge inside your LAN). Don't expose a Dumb AP's
  WAN port to an untrusted network.
- `image-build/build-asu.sh` uploads its `DEFAULTS` script to the public build server, so never put
  secrets there.
