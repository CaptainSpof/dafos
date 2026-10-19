# dafpi

Orange Pi 5 (aarch64), the first host built only from `flake-modules` aspects:
`configurations.nixos.dafpi.module`, no Snowfall compat layer.

- Install and recovery steps: [README.md](README.md). U-Boot is in SPI flash;
  never add a bootloader that writes to the NVMe's first sectors.
- Board settings live in the `orangepi5` aspect
  (`flake-modules/hardware/orangepi5.nix`); host-only settings here.
- Build `nix build .#nixosConfigurations.dafpi.config.system.build.toplevel` on
  dafbox (binfmt). Deploys build on the Pi (`remoteBuild`).
- Services move here from dafoltop one at a time; see the plan in
  `~/.claude/plans/je-veux-installer-nixos-functional-spark.md`.
- dafoltop's Home Assistant uses dafpi's Matter controller
  (`flake-modules/services/matter-server.nix`, `ws://192.168.0.15:5580/ws`,
  open to dafoltop only): Matter and Thread need IPv6, which dafoltop has none
  of by design. Thread's border router is meant to join it here, on the SONOFF
  dongle reflashed with OpenThread RCP once ZHA is retired.
