# Image build (optional)

Bake the roaming and Tailscale packages into a firmware image, so a freshly flashed router needs no
package downloads. `packages.txt` lists them (`-pkg` removes a default package).

```sh
TARGET=ipq806x/generic PROFILE=netgear_xr500 ./build-asu.sh          # official build server; bash + curl + jq
TARGET=ipq806x/generic PROFILE=netgear_xr500 ./build-imagebuilder.sh # local; x86_64 with Docker/Podman
```

Take `TARGET` and `PROFILE` for your device from <https://firmware-selector.openwrt.org>.
`VERSION` defaults to 25.12.5.

- `build-asu.sh` uses the public Attended Sysupgrade server. Anything passed as `DEFAULTS`
  (a first-boot script) is **uploaded and stored there**, so keep secrets out of it.
- `build-imagebuilder.sh` runs the official ImageBuilder container locally; `FILES_DIR` never
  leaves your machine.

Configure Wi-Fi with `roaming-setup.sh` after flashing.
