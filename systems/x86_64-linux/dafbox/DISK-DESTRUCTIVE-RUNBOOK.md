# dafbox — destructive disko rebuild runbook

Wipe both NVMes and reinstall onto a clean, fully-declarative btrfs **split-pool**
layout: ESP + 36 GB swap + a 100 GB btrfs `/` (single) on the Sabrent, and a `/home`
btrfs pool spanning the rest of the Sabrent + the whole 970 EVO (~1.28 TB,
`data=single`, `metadata=raid1`). The swap partition is sized for hibernate.

> See `DISK-POOL-PLAN.md` for the why; this file is the how. Nothing here has been
> applied — these are the steps and the configs to review.

---

## Facts this runbook is built on

| Thing | Value |
|---|---|
| OS disk | `/dev/disk/by-id/nvme-Sabrent_296E07051DFC02071186` (954 GB) |
| Pool disk | `/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_500GB_S466NX0KA31055B` (466 GB) |
| Bootloader | systemd-boot (UEFI) — ESP at `/boot` |
| `/home` data to preserve | **609 GB** |
| Channel | nixos-unstable (26.11) |
| Flake | `~/.config/dafos`, Snowfall, host `dafbox`, disko already wired in |

---

## Backup scope — decided

Of the 609 GB on `/home`, ~535 GB is re-downloadable Steam plus caches. We back up
**only the irreplaceable set** (identity, config, docs, browser profiles). Explicitly
**excluded** by choice: all games & game saves (Steam incl. `compatdata`, Paradox,
bottles/lutris/wine prefixes), Krita work, `Pictures`, `Videos`, caches.

Result: the backup is roughly **2–3 GB** (or ~25 GB if you include `~/Sync`), which
fits on a USB stick — or even the Freebox share's 38 GB free if `~/Downloads` is kept
modest. The runbook assumes a target mounted at `/mnt/backup`.

---

## Phase 0 — Backup & prep (on the running system)

**0.1 — Commit the flake state** so you can always rebuild the old layout if needed:
```sh
cd ~/.config/dafos
git add -A && git commit -m "dafbox: pre-disko snapshot" && git push
```

**0.2 — Pre-flight: make sure "skippable" really is.** Before trusting that repos and
Sync are safe to drop:
```sh
# any repo with unpushed commits or uncommitted changes?
for d in ~/Repositories/*/ ~/.config/dafos; do
  [ -d "$d/.git" ] || continue
  s=$(git -C "$d" status --porcelain); a=$(git -C "$d" log --branches --not --remotes --oneline)
  [ -n "$s$a" ] && echo "REVIEW: $d"
done
# is Syncthing actually replicating ~/Sync to another host? (else include it below)
systemctl --user status syncthing --no-pager 2>/dev/null | head -3
```
The `~/.config/sops/age/keys.txt` age key (189 B) is the single most important file —
without it, sops secrets won't decrypt on the new box. Back it up **separately and
securely** too, not just inside the bulk copy.

**0.3 — Run the backup (allowlist — copies only what matters).** `--relative` keeps
the `/home/daf/...` paths under the destination so restore is a straight reverse copy:
```sh
sudo mkdir -p /mnt/backup            # mount your USB / LAN target here first
DEST=/mnt/backup/home-dafbox

rsync -aHAX --info=progress2 --relative \
  /home/daf/.config/sops \
  /home/daf/.ssh \
  /home/daf/.gnupg \
  /home/daf/.pki \
  /home/daf/Documents \
  /home/daf/org \
  /home/daf/Music \
  /home/daf/.mozilla \
  /home/daf/.config/BraveSoftware \
  /home/daf/.config/chromium \
  /home/daf/Repositories \
  /home/daf/Downloads \
  /home/daf/Sync \
  "$DEST/"
```
Drop the last three lines (`Repositories`, `Downloads`, `Sync`) if 0.2 confirmed they
are pushed / replicated / not needed. **Excluded on purpose:** all games & saves,
Krita, `Pictures`, `Videos`, caches.

**0.4 — VERIFY the backup.** Do not skip. Confirm the age key and a file count:
```sh
test -s "$DEST/home/daf/.config/sops/age/keys.txt" && echo "age key OK"
diff <(cd /home && find daf/Documents -type f | sort) \
     <(cd "$DEST" && find home/daf/Documents -type f | sort) | head
```

**0.5 — Have the NixOS installer ready.** A current nixos-unstable / 25.11+ minimal
ISO on a USB stick. Also note your LUKS/user passwords if any.

---

**0.5 — Preserve the host SSH key (CRITICAL for sops).** dafbox's host key
`/etc/ssh/ssh_host_ed25519_key` derives the `root_dafbox` age identity
(`age1v7p9…`) that system secrets in `secrets/daf/*` are encrypted to. A reinstall
regenerates this key → system secrets stop decrypting. Preserving it also keeps the
machine's SSH identity stable. It's root-only, so copy it yourself (needs sudo):
```sh
mkdir -p /mnt/videos/dafbox-host-keys
sudo cp -a /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub \
          /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key.pub \
          /mnt/videos/dafbox-host-keys/ 2>/dev/null
sudo chown "$USER" /mnt/videos/dafbox-host-keys/*    # so restore is easy
ls -l /mnt/videos/dafbox-host-keys/
```
The private key will sit on the NAS in cleartext briefly — delete the folder after
the restore. (Alternative if you'd rather not preserve it: after reinstall, re-key
sops — `ssh-to-age` the new host key, update `root_dafbox` in `.sops.yaml`, run
`sops updatekeys secrets/daf/*.yaml`, commit. More steps; the admin age key in your
restored `~/.config/sops/age/keys.txt` can do it.)

## Phase 1 — Edit the flake (before wiping; commit & push)

These edits are applied to the repo now, but they **only take effect when you run
disko / nixos-install** — `nixos-rebuild` does not wipe disks. Still, do them on a
branch and push so the installer can pull them.

**1.1 — Create `systems/x86_64-linux/dafbox/disko.nix`** (full layout in §A below).

**1.2 — Edit `dafbox/default.nix`** — add the import:
```nix
imports = [ ./hardware.nix ./disko.nix ];
```

**1.3 — Edit `dafbox/hardware.nix`** — disko now generates the mounts and the swap
entry, so **remove** the hand-written `fileSystems."/"`, `."/home"`, `."/boot"` and
the `swapDevices` block. **Keep** the `/mnt/videos` CIFS entry, the `boot.initrd`
modules, networking, bluetooth, etc. Add btrfs to initrd to be safe:
```nix
boot.initrd.supportedFilesystems = [ "btrfs" ];
```

**1.4 — Swap & hibernate.** The layout uses a **36 GB swap partition** (> 30 GiB RAM,
so hibernate works). disko's `resumeDevice = true` (see §A) sets `boot.resumeDevice`
for you. NixOS enables hibernate automatically when a resumable swap device exists;
no zram. If you ever want both, you can add zram later at a *lower* priority than the
partition. To confirm hibernate is offered:
```nix
# usually already on; explicit if your modules disabled it:
# systemd.sleep.extraConfig = "";   # leave hibernate allowed
```

**1.5 — Commit & push:**
```sh
git checkout -b dafbox-disko && git add -A && git commit -m "dafbox: declarative disko btrfs split-pool" && git push -u origin dafbox-disko
```

---

## Phase 2 — Wipe, format, install (from the installer USB)

Boot the USB, get networking, then:

**2.1 — Get the flake:**
```sh
sudo -i
nix-shell -p git
git clone https://github.com/<you>/dafos /tmp/dafos   # or your remote
cd /tmp/dafos && git checkout dafbox-disko
```

**2.2 — Run disko (THIS ERASES BOTH NVMes):**
```sh
nix --experimental-features "nix-command flakes" run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --flake /tmp/dafos#dafbox \
  --yes-wipe-all-disks
```

**2.3 — Sanity-check the result:**
```sh
lsblk -f
btrfs filesystem show /mnt/home      # should list BOTH devices
btrfs filesystem usage /mnt/home     # Data,single  /  Metadata,RAID1
findmnt -R /mnt
```

**2.4 — Install:**
```sh
nixos-install --flake /tmp/dafos#dafbox --no-root-passwd
# set passwords after first boot, or via your declarative users + sops
```

**2.45 — Restore the host SSH key BEFORE first boot** (so sops decrypts on boot and
the machine keeps its identity). The new install just generated fresh host keys under
`/mnt/etc/ssh`; overwrite them with the preserved ones:
```sh
mount | grep -q /mnt/videos || mount -t cifs //192.168.0.254/Freebox/Vidéos /mnt/videos -o guest,vers=1.0
install -m600 /mnt/videos/dafbox-host-keys/ssh_host_ed25519_key     /mnt/etc/ssh/ssh_host_ed25519_key
install -m644 /mnt/videos/dafbox-host-keys/ssh_host_ed25519_key.pub /mnt/etc/ssh/ssh_host_ed25519_key.pub
install -m600 /mnt/videos/dafbox-host-keys/ssh_host_rsa_key         /mnt/etc/ssh/ssh_host_rsa_key 2>/dev/null
install -m644 /mnt/videos/dafbox-host-keys/ssh_host_rsa_key.pub     /mnt/etc/ssh/ssh_host_rsa_key.pub 2>/dev/null
# sanity: derived age identity must equal root_dafbox (age1v7p9…)
nix-shell -p ssh-to-age --run 'ssh-to-age < /mnt/etc/ssh/ssh_host_ed25519_key.pub'
```

**2.5 — Reboot** into the new system, remove the USB. First login uses the
`initialPassword` from your user module (`omgchangeme` unless overridden) — change it
with `passwd` after logging in.

> Alternative one-shot: `disko-install --flake .#dafbox --disk system <id> --disk
> data <id>` runs disko + nixos-install together. Or drive it from another machine
> with `nixos-anywhere`. Plain disko + nixos-install (above) is the most transparent.

---

## Phase 3 — Restore data

On the freshly booted system, logged in as `daf` (or via a root shell):
```sh
sudo mount /dev/disk/by-id/...your-backup... /mnt/backup     # if external
sudo rsync -aHAX --info=progress2 /mnt/backup/home-dafbox/home/daf/ /home/daf/
sudo chown -R daf:users /home/daf
# the age key comes back with the copy above; verify it landed:
test -s ~/.config/sops/age/keys.txt && chmod 600 ~/.config/sops/age/keys.txt
```
Then `nixos-rebuild switch --flake ~/.config/dafos#dafbox` to make sure sops secrets
decrypt and services (syncthing, etc.) come up clean.

---

## Phase 4 — Verify & finish

- `btrfs scrub start -B /home` — full integrity pass over the new pool.
- `btrfs filesystem usage /` and `/home` — confirm profiles and free space (~1.17 TB).
- Take a test snapshot + confirm rollback works:
  `btrfs subvolume snapshot -r /home /home/.snapshots/test`
- Confirm boot entries in systemd-boot, and that `/mnt/videos` automounts.
- Merge `dafbox-disko` → main once happy; the box is now reproducible from the flake.

---

## §A — `disko.nix` (draft to review)

```nix
{
  disko.devices = {
    disk = {
      system = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Sabrent_296E07051DFC02071186";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            swap = {
              size = "36G";                  # > 30 GiB RAM → hibernate-capable
              content = {
                type = "swap";
                resumeDevice = true;         # sets boot.resumeDevice automatically
              };
            };
            root = {
              size = "100G";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-L" "nixos" ];
                subvolumes = {
                  "@"          = { mountpoint = "/";         mountOptions = [ "compress=zstd" "noatime" ]; };
                  "@nix"       = { mountpoint = "/nix";      mountOptions = [ "compress=zstd" "noatime" ]; };
                  "@log"       = { mountpoint = "/var/log";  mountOptions = [ "compress=zstd" "noatime" ]; };
                  "@snapshots" = { mountpoint = "/.snapshots"; };
                };
              };
            };
            home = {
              size = "100%";                 # rest of the Sabrent → first pool member
              content = {
                type = "btrfs";
                # mkfs runs ONCE here, creating the multi-device fs across both
                # `home` partitions. data=single (sum capacity), metadata=raid1.
                extraArgs = [
                  "-f" "-L" "home"
                  "-d" "single" "-m" "raid1"
                  "/dev/disk/by-partlabel/disk-data-home"   # the EVO partition (see note)
                ];
                subvolumes = {
                  "@home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
                };
              };
            };
          };
        };
      };

      data = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_500GB_S466NX0KA31055B";
        content = {
          type = "gpt";
          partitions = {
            home = {
              size = "100%";
              # No filesystem content here: this partition is consumed by the
              # mkfs.btrfs invoked in the `system` disk's `home` partition above.
              content = null;
            };
          };
        };
      };
    };
  };
}
```

> **Multi-device btrfs — verified against disko rev `ff8702b4` (your `flake.lock`).**
> I rendered the actual create script disko generates for this exact config and
> checked it. Findings:
>
> - The home filesystem is created by a single command:
>   `mkfs.btrfs /dev/disk/by-partlabel/disk-system-home -f -L home -d single -m raid1 /dev/disk/by-partlabel/disk-data-home`
>   — i.e. disko's btrfs type runs `mkfs.btrfs <device> <extraArgs…>`, so listing the
>   EVO partition in `extraArgs` makes it the second device. ✓
> - **Ordering is correct:** disko processes the `data` disk (EVO) first — partitions
>   it, runs `partprobe` + `udevadm settle` — *before* the `system` disk's home
>   `mkfs.btrfs` runs. So the second device exists when the pool is created. ✓
> - The EVO partition uses `content = null`, so disko partitions it but does **not**
>   format it separately — it's consumed only by the mkfs above. ✓
> - **The one fix:** reference the EVO partition by its disko-assigned partlabel
>   `/dev/disk/by-partlabel/disk-data-home` (not a `by-id …-part1` path). disko names
>   every partition `disk-<disk>-<partition>`, so this is guaranteed to match what it
>   just created. (Already applied above.)
>
> Caveat worth knowing: disko's btrfs type doesn't *declare* a dependency edge to the
> second device — the correct ordering comes from `data` sorting before `system` in
> the device list. Keep the disk named `data` (or any name sorting before `system`)
> so the EVO is always partitioned first. `/home` is not in initrd, and udev's
> `btrfs device scan` registers both members before it mounts, so multi-device mount
> is fine; `boot.initrd.supportedFilesystems = [ "btrfs" ]` (step 1.3) covers it.

---

## Risk recap (you chose capacity over redundancy)

`data=single` across two disks means **either NVMe dying loses all of `/home`**.
`metadata=raid1` keeps the *filesystem* mountable through small glitches but does
**not** protect your files. Keep a real backup routine after the rebuild (this is the
perfect time to set up `btrfs send`-based snapshots to an external/LAN target).
`/` lives only on the Sabrent, so an EVO failure won't stop the machine from booting.
