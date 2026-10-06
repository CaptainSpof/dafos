# NVMe layout, applied by nixos-anywhere at install time (see ./README.md).
# /boot is FAT so U-Boot's extlinux scan finds it without an ext4 driver
# quirk; everything else is a single ext4 root.
{
  configurations.nixos.dafpi.module = {
    disko.devices.disk.nvme = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
