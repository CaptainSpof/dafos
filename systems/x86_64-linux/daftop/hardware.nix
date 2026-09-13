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
    common-pc-laptop
    common-pc-ssd
  ];

  # linux-firmware 20260910 broke DMCUB firmware loading on this Radeon 680M
  # (Rembrandt/YELLOW_CARP): amdgpu logs "failed to load ucode DMCUB(0x3F)" /
  # PSP LOAD_IP_FW error and never registers a DRM device, so no compositor
  # can start at all. Same regression reported upstream:
  #   https://discuss.cachyos.org/t/regression-linux-firmware-amdgpu-20260910-1-dmcub-fails-to-load-on-amd-radeon-680m-rembrandt-causing-slow-boot-and-visual-glitches/35623
  # Pin back to the last known-good tag until DMCUB is fixed again for
  # Rembrandt. Scoped to this host: other GPUs may need the newer firmware.
  nixpkgs.overlays = [
    (_final: prev: {
      linux-firmware = prev.linux-firmware.overrideAttrs (_old: rec {
        version = "20260810";
        src = prev.fetchFromGitLab {
          owner = "kernel-firmware";
          repo = "linux-firmware";
          tag = version;
          hash = "sha256-P/fPpqaatp8Z2GV+I/OChiWGn6AhV+8w1RMFuX/LqHc=";
        };
      });
    })
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    binfmt.emulatedSystems = [ "aarch64-linux" ];
    initrd = {
      availableKernelModules = [
        "ahci" # SATA devices on modern AHCI controllers
        "nvme"
        "sd_mod" # SCSI, SATA, and IDE devices
        "thunderbolt"
        "uas"
        "usb_storage" # USB mass storage devices
        "usbhid" # USB human interface devices
        "xhci_pci" # USB 3.0
      ];
      luks.devices."crypted".device = "/dev/disk/by-uuid/2740b97b-a34c-43d5-9a5b-bb86521690ca";
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    "/home" = {
      device = "/dev/disk/by-label/home";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };
  };

  swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };

  hardware.sensor.iio.enable = true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  powerManagement.powertop.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
