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
  #
  # The media pool lives on dafoltop and is exported read-only over NFSv4 (see
  # modules/nixos/services/media-export). It is mounted by dafoltop's LAN
  # address, not its tailnet name, so it keeps working when tailscale is down.
  # `soft` so a powered-off dafoltop gives an error instead of a hung Dolphin.
  fileSystems."/mnt/data" = {
    depends = [ "/" ];
    device = "192.168.0.10:/mnt/data";
    fsType = "nfs";
    options = [
      "ro"
      "nfsvers=4.2"
      "soft"
      "timeo=50"
      "retrans=2"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=300"
      "x-systemd.mount-timeout=10s"
    ];
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
