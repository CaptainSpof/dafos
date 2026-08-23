{
  lib,
  modulesPath,
  inputs,
  pkgs,
  ...
}:

let
  inherit (inputs) nixos-hardware;
in
{
  imports = with nixos-hardware.nixosModules; [
    (modulesPath + "/installer/scan/not-detected.nix")
    common-cpu-amd
    common-cpu-amd-pstate
    common-gpu-amd
    common-pc
    common-pc-ssd
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    # RDNA3 (Navi 31) gates manual fan-curve/overclocking sysfs behind the
    # overdrive feature mask; without it amdgpu.ppfeaturemask defaults to a
    # restricted set and tools like LACT can't read/write fan curves.
    kernelParams = [ "amdgpu.ppfeaturemask=0xffffffff" ];

    binfmt.emulatedSystems = [ "aarch64-linux" ];
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "uas"
        "usb_storage"
        "sd_mod"
      ];
      supportedFilesystems = [ "btrfs" ];
    };
    kernelModules = [
      "tcp_bbr"
      "kvm-amd"
      "uhid"
      # The board's NCT6799D Super-I/O owns CPU_FAN/AIO_PUMP/CHA_FAN. Without
      # this driver the only writable PWM in sysfs is the GPU's, so the CPU
      # cooler curve stays in the BIOS and coolercontrold logs the chip as
      # "skipped_no_modprobe". asus-ec-sensors only *reads* CPU_Opt RPM.
      "nct6775"
    ];
  };

  # `/`, `/home`, `/boot`, `/nix`, `/var/log` and swap are now declared in
  # ./disko.nix (disko generates the fileSystems + swapDevices entries).
  # Only the network share remains hand-defined here.
  fileSystems = {
    "/mnt/videos" = {
      depends = [ "/" ];
      device = "//192.168.0.254/Freebox/Vidéos";
      fsType = "cifs";
      options = [
        "guest"
        "noauto"
        "uid=1000"
        # SMB1 (vers=1.0) is deprecated/insecure; modern Freeboxes speak SMB2/3.
        # Fall back to "2.1" or "2.0" if the mount fails, or "1.0" for a very old Freebox.
        "vers=3.0"
        # noserverino: Freebox doesn't report stable server inode numbers; silences
        # the "Autodisabling server inode numbers"/"Hardlinks will not be recognized" warnings.
        "noserverino"
        "nounix"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s"
      ];
    };
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  networking.interfaces.eno1.wakeOnLan.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
