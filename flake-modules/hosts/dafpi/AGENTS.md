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
