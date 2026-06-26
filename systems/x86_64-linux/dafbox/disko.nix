{
  # Declarative disk layout for dafbox — btrfs split-pool.
  # `/` is a single-device btrfs on the Sabrent; `/home` is one btrfs filesystem
  # spanning the rest of the Sabrent + the whole 970 EVO (data=single, metadata=raid1).
  # Verified against disko rev ff8702b4 — see DISK-DESTRUCTIVE-RUNBOOK.md.
  #
  # NOTE: the disk named `data` (the EVO) MUST sort before `system` so disko
  # partitions it before the home mkfs runs. Do not rename it.
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
              size = "36G"; # > 30 GiB RAM → hibernate-capable
              content = {
                type = "swap";
                resumeDevice = true; # sets boot.resumeDevice automatically
              };
            };
            root = {
              size = "100G";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" "-L" "nixos" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                  };
                };
              };
            };
            home = {
              size = "100%"; # rest of the Sabrent → first pool member
              content = {
                type = "btrfs";
                # mkfs runs ONCE here, creating the multi-device fs across both
                # `home` partitions. data=single (sum capacity), metadata=raid1.
                # The EVO partition is referenced by its disko partlabel.
                extraArgs = [
                  "-f"
                  "-L"
                  "home"
                  "-d"
                  "single"
                  "-m"
                  "raid1"
                  "/dev/disk/by-partlabel/disk-data-home"
                ];
                subvolumes = {
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
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
              # No filesystem content: this partition is consumed by the
              # mkfs.btrfs invoked in the `system` disk's `home` partition above.
              content = null;
            };
          };
        };
      };
    };
  };
}
