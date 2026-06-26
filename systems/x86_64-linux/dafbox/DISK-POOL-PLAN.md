# dafbox — declarative partitioning + disk pool plan

**Goal:** extend `/home` capacity by pooling in the currently-unused NVMe, managed
declaratively with [disko](https://github.com/nix-community/disko), **without losing
existing data**.

---

## 1. Current state (measured on the running box)

```
nvme0n1  Sabrent            953.9G   ← OS disk, in use
 ├─p1  1023M  vfat  /boot   (label boot, ESP)
 ├─p2     8G  swap  [SWAP]  (label swap)
 ├─p3   191G  ext4  /       (label nixos, 67G used / 38%)
 └─p4 753.9G  ext4  /home   (label home, 609G used / 87%)  ← the squeeze

nvme1n1  Samsung 970 EVO    465.8G   ← EMPTY, no partitions  ← the disk to add
```

RAM 30 GiB · 16 threads · AMD · **no ECC**. Disko input + module are already wired
into the flake (`disko.url`, `disko.nixosModules.disko` in `systems.modules.nixos`),
so no flake plumbing is needed.

The two disks are **different sizes** and **one already holds the OS + data**. That
single fact rules out the tidy "mirror two identical disks" story and drives every
decision below.

---

## 2. The core tension: disko vs. "keep my data"

Disko is a **destructive, install-time** tool. It declares a layout and *creates*
it (`wipefs` → partition → `mkfs`). It does **not** migrate or adopt existing data
in place. So "make `/home` declarative with disko" and "keep the 609 GB already on
`/home`" cannot both be true on the *same disk* in one step.

There are two honest ways to reconcile this:

- **Path A — Non-destructive bridge now, full disko later (recommended).**
  Get the capacity today without a reinstall; let disko fully own the layout when
  you next have a backup + downtime window.
- **Path B — Clean disko reinstall now.** Back up `/home`, wipe both disks, let
  disko declare everything, restore. Cleanest end state, but it's a reinstall.

A pure "disko adopts my live `/home` in place" option does not exist.

---

## 3. Filesystem / tool review (for a capacity pool, no redundancy)

You chose **more capacity** and **keep existing data**, so the comparison is about
which pooling tool best sums two mismatched NVMes while letting you grow later.

| Option | Pools mismatched disks? | Non-destructive on existing `/home`? | Grow by adding disks | Snapshots / checksums | disko fit | Verdict |
|---|---|---|---|---|---|---|
| **btrfs (single data, raid1 metadata)** | Yes — `single` uses full capacity of each | **Yes** via in-place `btrfs-convert` of the ext4 `/home`, then `btrfs device add` | `btrfs device add` live, then rebalance | Yes (snapshots, checksums) | First-class (`type = "btrfs"`) | **Recommended** |
| mergerfs (union FS) | Yes — file-level JBOD | **Yes** — leaves ext4 untouched, unions a second FS over it | Add a disk, add a branch | No | Weak (disko just formats each disk independently) | Best *safety* on disk loss; least "declarative pool" |
| LVM linear | Yes — linear LV across PVs | No — current `/home` is raw ext4, **not** a PV, so needs migration anyway | `vgextend` + `lvextend` | No (thin/snapshots clunky) | Supported but no in-place adopt | Skip — no advantage here |
| ZFS | Awkward — vdev geometry is rigid; mismatched disks waste space or force stripe | No — cannot convert ext4 in place; needs copy/reinstall | Add vdev (can't easily shrink/rebalance) | Excellent (send/recv) | First-class | Great FS, wrong fit for *non-destructive capacity* here |
| bcachefs | Yes, designed for it | No in-place ext4 convert | Yes | Yes | Limited | Too new; no non-destructive path |

### Why btrfs wins for *your* constraints

- **It's the only proper pooled FS with a non-destructive on-ramp.** `btrfs-convert`
  turns the existing ext4 `/home` into btrfs *keeping the data*, then
  `btrfs device add /dev/nvme1n1` instantly grows the pool. Capacity becomes
  ~754 GB + ~466 GB ≈ **1.2 TB** for `/home`.
- **Mismatched sizes are a non-issue** in `single` data profile — it just consumes
  the full capacity of each device.
- **"Pool you add disks to" is native**: `btrfs device add` / `remove` / `balance`
  live, no downtime. Exactly your mental model.
- **Free upgrade later:** you can `balance` metadata to `raid1` for cheap metadata
  protection now, and convert *data* to `raid1` later if you add a third disk and
  decide you want redundancy — without rebuilding.
- **disko-native**, so the eventual clean layout stays fully declarative.

### The honest caveats (because you picked "capacity", not "redundancy")

- `single` data = **no redundancy**. With two NVMes pooled, **either drive dying
  loses the pool.** NVMe does fail. Backups are mandatory — your Freebox CIFS share
  (`/mnt/videos`, ~917 GB) or an external disk. (Set metadata to `raid1` so the FS
  itself survives a transient hiccup, but that does not protect data.)
- `btrfs-convert` is reliable but **back up first**. After converting, mount, verify,
  then delete the `ext2_saved` subvolume to reclaim the old ext4 image and make the
  conversion permanent (you lose ext4-rollback once you do).
- btrfs needs the right initrd bits for multi-device; NixOS handles this when the FS
  is declared, but it's why we keep multi-device strictly under `/home`, **not** root.
- Avoid btrfs **raid5/6** (still not production-trustworthy) — not relevant here
  since you want capacity, but worth stating.

**Lowest-risk alternative if a single-disk failure killing everything is
unacceptable to you:** mergerfs. It keeps your ext4 `/home` exactly as-is, formats
the 970 EVO independently, and presents a merged `/home`. A dead disk then only loses
*that disk's* files, not both. The trade: no snapshots/checksums and it isn't really
a disko-managed block pool. I led with btrfs because it matches "declarative pool via
disko"; mergerfs is the call if safety beats elegance.

---

## 4. Recommended plan — Path A (phased)

### Phase 0 — Backup & safety (do not skip)

1. Confirm a current backup of `/home` (609 GB). Targets: external USB/NVMe, or the
   Freebox share. Verify a few restores.
2. Snapshot the flake state: `git -C ~/.config/dafos commit -am "pre-disko"`.
3. Note current labels/UUIDs (already captured in §1) in case of rollback.

### Phase 1 — Add capacity now, non-destructive

1. **Bring `/home` onto btrfs in place** (one-time, manual, from a live/console with
   `/home` unmounted — easiest from a NixOS installer USB or a root shell with the
   user logged out):
   ```sh
   umount /home
   btrfs-convert /dev/nvme0n1p4        # ext4 -> btrfs, keeps data
   mount /dev/nvme0n1p4 /mnt && btrfs filesystem show /mnt   # verify
   ```
2. **Add the empty NVMe to the pool** and rebalance to spread data:
   ```sh
   btrfs device add -f /dev/nvme1n1 /home
   btrfs balance start -dconvert=single -mconvert=raid1 /home   # data=single, metadata mirrored
   ```
   `/home` is now ~1.2 TB across both disks.
3. **Make it declarative.** Add `disko.devices` describing the **new disk only**
   (`nvme1n1`) as a btrfs member, and migrate the `fileSystems` entries from
   `hardware.nix` into the disko config (disko generates `fileSystems` for you —
   keeping both would conflict). Importantly: **declaring `disko.devices` does NOT
   wipe anything on `nixos-rebuild`** — disko only formats when you explicitly run
   its CLI. So the OS disk stays safe; rebuild just consumes the generated mounts.
4. Once converted & verified, delete the rescued ext4 image to reclaim space:
   ```sh
   btrfs subvolume delete /home/ext2_saved
   ```

### Phase 2 — Clean, fully-declarative layout (optional, later)

When you next have a backup + a maintenance window and want the *whole* box to be
disko-reproducible from scratch: back up `/home`, boot the installer, run
`disko --mode destroy,format,mount --flake .#dafbox`, `nixos-install`, restore data.
End state: ESP + swap + btrfs `/` on the Sabrent, and a btrfs `home` pool spanning a
Sabrent partition + the whole 970 EVO in `single` mode. Skeleton in §5.2.

---

## 5. Concrete disko configs (drafts to review — not yet applied)

These live in a new `systems/x86_64-linux/dafbox/disko.nix`, imported from
`dafbox/default.nix` (`imports = [ ./hardware.nix ./disko.nix ];`). The matching
`fileSystems`/`swapDevices` blocks then come out of `hardware.nix`.

### 5.1 Phase 1 — new disk only (`nvme1n1`), non-destructive to the OS disk

> Used to make the *added* disk declarative. Existing partitions on `nvme0n1`
> stay described by `fileSystems` until Phase 2. The btrfs pool itself spans both
> disks at runtime (created manually in Phase 1); this file declares the new member.

```nix
{
  disko.devices.disk.data = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_500GB_S466NX0KA31055B";
    content = {
      type = "gpt";
      partitions.pool = {
        size = "100%";
        content = {
          type = "btrfs";
          # part of the existing /home btrfs pool; do not reformat
          extraArgs = [ ];
        };
      };
    };
  };
}
```
*(Use the `/dev/disk/by-id/...` path — stable across reboots, unlike `nvme1n1`.)*

### 5.2 Phase 2 — full declarative layout (destructive; for the eventual reinstall)

```nix
{
  disko.devices = {
    disk = {
      system = {                      # Sabrent 954G
        type = "disk";
        device = "/dev/disk/by-id/nvme-Sabrent_296E07051DFC02071186";
        content = {
          type = "gpt";
          partitions = {
            ESP  = { size = "1G";  type = "EF00";
                     content = { type = "filesystem"; format = "vfat";
                                 mountpoint = "/boot"; mountOptions = [ "umask=0077" ]; }; };
            swap = { size = "8G";  content = { type = "swap"; }; };
            root = { size = "200G"; content = {
                       type = "btrfs"; extraArgs = [ "-f" ];
                       subvolumes = {
                         "/rootfs" = { mountpoint = "/"; };
                         "/nix"    = { mountpoint = "/nix"; mountOptions = [ "compress=zstd" "noatime" ]; };
                       }; }; };
            pool = { size = "100%"; content = {
                       type = "btrfs"; extraArgs = [ "-f" "-d" "single" "-m" "raid1" ];
                       subvolumes."/home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" ]; };
                     }; };
          };
        };
      };
      data = {                        # 970 EVO 466G — second member of the home pool
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_500GB_S466NX0KA31055B";
        content = { type = "gpt"; partitions.pool = { size = "100%";
                    content = { type = "btrfs"; extraArgs = [ "-f" ]; }; }; };
      };
    };
  };
}
```
*(Multi-device btrfs across the two `pool` partitions is created by disko in one
`mkfs.btrfs -d single -m raid1`; the second disk's partition joins the same FS.)*

---

## 6. Open questions for you

1. **Redundancy tolerance:** OK that, in the pooled `single` setup, one NVMe dying
   loses `/home`? If not, say so — mergerfs (isolated loss) or a smaller mirrored
   pool changes the design.
2. **Where's the backup landing** for Phase 0 (and eventual Phase 2)? Freebox share,
   external disk, or both?
3. **Phase 2 appetite:** do you want me to fully spec the backup→reinstall→restore
   runbook now, or keep Phase 1 as the stopping point and revisit later?
4. **swap:** keep the 8 GB partition, or move to a btrfs swapfile / zram while we're
   in here?

Once you've reviewed, I can turn the agreed path into the actual `disko.nix` +
`default.nix`/`hardware.nix` edits and a step-by-step execution runbook.
