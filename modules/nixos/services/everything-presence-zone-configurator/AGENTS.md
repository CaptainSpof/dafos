# everything-presence-zone-configurator

Upstream ships this only as a Home Assistant Supervisor add-on or a Docker
image. dafos runs it as a plain node service beside the native home-assistant,
with the npm workspace built in
[../../../../packages/everything-presence-zone-configurator](../../../../packages/everything-presence-zone-configurator)
the way the Dockerfile's `standalone` stage does.

Four non-obvious constraints:

- The backend resolves its device profiles and version string relative to the
  **working directory**, hence the wrapper's `--chdir`.
- It calls `process.exit` when HA is unreachable at startup. `Restart=always`
  with `RestartSec=30` is the reconnect strategy — there is no internal retry to
  fix.
- The HA long-lived token lives in `secrets/daf/everything-presence.yaml` and
  reaches the service through systemd `LoadCredential`
  (`HA_LONG_LIVED_TOKEN_FILE=%d/ha-token`), so `DynamicUser` never has to read
  `/run/secrets`.
- The OTA LAN IP is pinned on dafoltop because upstream's auto-detection only
  skips docker, `br-`, `veth`, `tun` and `wg` interfaces.

The in-app OTA button needs device firmware **≥ 1.4.x** — it calls the ESPHome
`set_update_manifest` action. Flashing over the network uses port 3232 and is
unauthenticated; the vendor's web flash page is USB-only and Firefox has no Web
Serial. The ld2450 manifest has no suffix.
