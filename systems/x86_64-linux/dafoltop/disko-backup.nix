{
  # The 1 TB Samsung in the dock's second bay: the local restic target.
  #
  # Its own file, deliberately. disko's destroy/format scripts act on EVERY disk
  # in `disko.devices`, so formatting this one from the shared config would also
  # target the media disk. Run disko against this file alone:
  #
  #   sudo nix run github:nix-community/disko/latest -- --dry-run --mode destroy \
  #     --root-mountpoint /run/disko-backup ./systems/x86_64-linux/dafoltop/disko-backup.nix
  #
  # (then read the script: only the ata-SAMSUNG path may appear), and repeat
  # without --dry-run for `destroy`, then `format`. File mode honours
  # --root-mountpoint, so `umount -Rv` never touches /mnt.
  #
  # `device` is the drive's own id, not the dock's `usb-ASMT_…-0:1` bay path and
  # never /dev/sdX: the dock re-enumerates when a drive is added or removed
  # (2026-10-01: sda became sdb), and a bay path would point at the wrong disk
  # if the drives were swapped. The generated fstab uses by-partlabel anyway.
  disko.devices.disk.backup = {
    type = "disk";
    device = "/dev/disk/by-id/ata-SAMSUNG_HD103SI_S1XGJ9BS808765";
    content = {
      type = "gpt";
      partitions.data = {
        size = "100%";
        content = {
          type = "btrfs";
          extraArgs = [
            "-f"
            "-L"
            "backup"
          ];
          subvolumes."@backup" = {
            mountpoint = "/mnt/backup";
            mountOptions = [
              # no compress=: restic already compresses and encrypts its data
              "noatime"
              "nofail" # a missing dock must never block boot
              "x-systemd.device-timeout=10s"
            ];
          };
        };
      };
    };
  };
}
