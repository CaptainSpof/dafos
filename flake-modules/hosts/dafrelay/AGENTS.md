# dafrelay

Raspberry Pi 4 B (Rev 1.2, 4 GB RAM, aarch64), destined for a family member's
home: off-site copy of dafoltop's photos, later an immich-kiosk fallback. Pure
dendritic host like dafpi.

- Install and recovery: [README.md](README.md). The image is the whole system
  (`.#packages.aarch64-linux.dafrelay-image`), written to the USB key; there is
  no installer phase.
- Board settings live in the `raspberrypi4` aspect
  (`flake-modules/hardware/raspberrypi4.nix`); host-only settings here.
- The OS is on a no-name USB key: never put bulk or frequently rewritten data on
  `/`. Backups go to the dock disks.
- Off-site and unattended: every change must leave it reachable over Tailscale
  after a power cut, with nobody on site.
