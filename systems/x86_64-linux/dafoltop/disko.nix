{
  # Declarative layout for the USB-attached 4 TB media disk ONLY.
  # `/`, `/boot` and `/home` are NOT declared here -- they stay in
  # hardware.nix. That is a deliberate exception to the systems/AGENTS.md rule
  # ("where a host uses disko, the filesystem declarations live in its
  # disko.nix"): adopting the live ext4 root into disko would mean a
  # destructive reinstall of the live house, for no gain.
  #
  # `device` is the dock's by-id path, not the drive's: this bridge (ASMedia
  # 174c:55aa) reports an all-zero serial, so by-id identifies "whatever is in
  # this dock" rather than a specific disk. Fine as long as only one drive
  # ever lives in this disko.devices entry -- see DISK-PLAN.md.
  disko.devices.disk.media = {
    type = "disk";
    device = "/dev/disk/by-id/usb-ASMT_USB_3.0_Destop_H_00000000000000000000-0:0";
    content = {
      type = "gpt";
      partitions.data = {
        size = "100%";
        content = {
          type = "btrfs";
          extraArgs = [
            "-f"
            "-L"
            "media"
          ];
          subvolumes."@data" = {
            mountpoint = "/mnt/data";
            mountOptions = [
              "compress=zstd:1" # cheap; media is mostly incompressible, metadata isn't
              "noatime"
              "nofail" # a missing dock must never block boot
              "x-systemd.device-timeout=10s" # ... and must not wait 90s for it either
            ];
          };
        };
      };
    };
  };
}
