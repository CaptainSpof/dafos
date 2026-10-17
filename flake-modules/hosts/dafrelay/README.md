# dafrelay — install runbook

Raspberry Pi 4 B. NixOS lives on a USB key (59 GB, no-name SMI controller);
backups go to a FIDECO dual-bay USB dock. No SD card, except once if the EEPROM
predates USB boot.

Everything runs from dafbox (binfmt `aarch64-linux`), in the repo.

## 1. Build and write the key (~20 min)

```bash
nix build .#packages.aarch64-linux.dafrelay-image
lsblk -d -o NAME,SIZE,TRAN,MODEL       # find the key (59G, usb, "USB DISK")
sudo dd if=result/sd-image/nixos-image-*.img of=/dev/sdX bs=4M conv=fsync status=progress
```

The image is the whole system: FIRMWARE (Pi firmware + U-Boot) and NIXOS_SD
(root). The root partition grows to fill the key on first boot.

## 2. Boot (~5 min)

Key in a **blue** (USB 3) port, Ethernet, official 5.1 V / 3 A supply. It
announces itself as `dafrelay.local`:

```bash
ssh daf@dafrelay.local
free -h                                # record the RAM in ./AGENTS.md
passwd                                 # the initial one is the repo default
sudo tailscale up
```

No network after 2 min and no activity LED: the EEPROM cannot boot from USB.
Write Raspberry Pi Imager's _Misc utility images → Bootloader → USB Boot_ to a
micro-SD, boot it once (green LED blinks steadily when done), remove it, retry.

## 3. Secrets

```bash
ssh daf@dafrelay.local 'cat /etc/ssh/ssh_host_ed25519_key.pub' | nix run nixpkgs#ssh-to-age
```

Add it to `.sops.yaml` as `&root_dafrelay`, then `sops updatekeys` on the files
dafrelay must read (dafos-secrets skill).

## Later deploys

```bash
deploy -s .#dafrelay --interactive-sudo true
```
