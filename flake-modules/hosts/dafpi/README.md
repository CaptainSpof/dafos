# dafpi — install runbook

Orange Pi 5 (RK3588S, 16 GB) with an M.2 NVMe SSD. U-Boot lives in the board's
SPI flash; NixOS lives entirely on the NVMe. The SD card is only used once, to
get there.

Everything below runs from dafbox (it has
`boot.binfmt.emulatedSystems =
[ "aarch64-linux" ]`), in the repo.

## 1. Build and write the installer SD card (~10 min)

```bash
nix build .#packages.aarch64-linux.dafpi-installer
sudo dd if=result/sd-image/dafpi-installer.img of=/dev/sdX bs=4M conv=fsync status=progress
```

The image carries U-Boot (`pkgs.ubootOrangePi5`) at 32 KiB, so it boots even
with an empty SPI flash (the RK3588 boot ROM tries SPI, then eMMC, then SD).

## 2. Boot it and flash U-Boot to SPI (~5 min)

Insert the SD card and the NVMe, plug Ethernet, power on. The installer
announces itself over mDNS within a minute or so; no screen or keyboard is
needed:

```bash
ssh root@dafpi-installer.local
cat /proc/mtd                      # expect an mtd0 for the SPI NOR
flashcp -v /etc/dafpi/u-boot-rockchip-spi.bin /dev/mtd0
lsblk /dev/nvme0n1                 # the SSD must be visible
```

If `/proc/mtd` is empty: `modprobe spi_rockchip_sfc` and retry.

## 3. Install onto the NVMe (~20 min, mostly copying the closure)

```bash
nix run nixpkgs#nixos-anywhere -- --phases disko,install --flake .#dafpi root@dafpi-installer.local
```

`disko,install` skips the kexec phase: the installer is already NixOS. The NVMe
is wiped and partitioned by `./disko.nix`.

## 4. Reboot from NVMe

Power off, remove the SD card, power on. U-Boot (SPI) finds
`/boot/extlinux/extlinux.conf` on the NVMe. Then:

- Freebox: give dafpi a fixed DHCP lease.
- `ssh daf@<ip>`; set a password (`passwd`), the initial one is the repo
  default.
- `sudo tailscale up`.

## 5. Secrets

The host's age identity comes from its SSH host key:

```bash
ssh daf@dafpi 'cat /etc/ssh/ssh_host_ed25519_key.pub' | nix run nixpkgs#ssh-to-age
```

Add it to `.sops.yaml` as `&root_dafpi`, plus a `&user_daf_dafpi` key if
user-level secrets are needed, then `sops updatekeys` on the files dafpi must
read (dafos-secrets skill). Also put a `daf@dafpi.pem` key in `~/.ssh` on dafpi:
the openssh aspect points every Host block at it.

## Later deploys

```bash
nix run .#deploy -- .#dafpi
```

deploy-rs builds on the Pi itself (`remoteBuild`), which is faster than
qemu-user on dafbox.

## Recovery

- No boot from NVMe: plug the SD card back in; the boot ROM tries SPI first, so
  if U-Boot in SPI is broken, erase it from the SD system
  (`flash_erase /dev/mtd0 0 0`) and the board falls back to the SD's U-Boot.
- Serial console: 3-pin debug header, 1 500 000 baud, `console=ttyS2`.

## Lessons from the first install (2026-10-06)

- **Power**: the first USB-C supply left the board in a reset loop (red LED
  only, no green heartbeat, never on the network). A phone charger rated
  5 V / 3 A booted it. The board only takes 5 V; budget 4 A with the NVMe.
- **SPI from maskrom**: an old bootloader in SPI would win over the SD (the
  boot ROM tries SPI first). That was suspected but never confirmed — the
  power supply alone explains the first failure. Writing ours from dafbox
  in maskrom mode works without any SD and replaces README step 2: unplug,
  data USB-C cable to dafbox, hold MaskROM while plugging
  power, then `rkdeveloptool db <loader>` (rkbin's
  `RKBOOT/RK3588MINIALL.ini` through `tools/boot_merger`), `cs 9`,
  `wl 0 u-boot-rockchip-spi.bin`.
- **NVMe dropping out ~40 s after boot** (timeouts, failed reset): NVMe
  APST / PCIe ASPM. The orangepi5 aspect disables both on the kernel
  command line.
