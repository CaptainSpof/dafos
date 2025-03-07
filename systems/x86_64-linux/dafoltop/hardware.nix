{
  lib,
  modulesPath,
  inputs,
  pkgs,
  ...
}:

let
  inherit (inputs) nixos-hardware;
  inherit (lib) getExe;

  freeboxHostname = "Freebox-Server.local";
  freeboxCifsOptions = [
    "sec=none"
    "uid=daf"
    "gid=yahrr"
    "file_mode=0770"
    "dir_mode=0770"
    "vers=3"
    "nounix"
    "x-systemd.automount"
    "noauto"
    "x-systemd.requires=wait-freebox-available.service"
    "x-systemd.after=wait-freebox-available.service"
    # "x-systemd.idle-timeout=60"
    # "x-systemd.device-timeout=30s"
    # "x-systemd.mount-timeout=30s"
  ];
in
{
  imports = with nixos-hardware.nixosModules; [
    (modulesPath + "/installer/scan/not-detected.nix")
    common-cpu-intel
    common-pc
    common-pc-ssd
    common-pc-laptop
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [
      "tcp_bbr"
      "uhid"
    ];

    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
        "rtsx_pci_sdmmc"
        "uhid"
      ];
      kernelModules = [ "kvm-intel" ];
    };
    supportedFilesystems = [ "cifs" ];
    extraModulePackages = [ ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/0c5fdf84-5560-4d25-888b-1788147d0c2c";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/D0D5-28D9";
      fsType = "vfat";
    };

    "/home" = {
      device = "/dev/disk/by-uuid/d5455556-00a8-401b-8c06-294f431fa6ee";
      fsType = "ext4";
    };

    "/mnt/audio" = {
      device = "//${freeboxHostname}/Freebox/Audio";
      fsType = "cifs";
      options = freeboxCifsOptions;
    };

    "/mnt/videos" = {
      device = "//${freeboxHostname}/Freebox/Vidéos";
      fsType = "cifs";
      options = freeboxCifsOptions;
    };
  };

  systemd.services.wait-freebox-available = {
    description = "Waiting for Freebox to become reachable.";
    wantedBy = [ "network-online.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];

    serviceConfig = {
      ExecStart = "${getExe pkgs.bash} -c 'until ${getExe pkgs.unixtools.ping} -qW 1 -c1 ${freeboxHostname}; do sleep 1; done'";
      RemainAfterExit = "yes";
      TimeoutStopSec = 120;
      PrivateTmp = false;
      Type = "oneshot";
    };
  };

  swapDevices = [ ];

  networking = {
    # Enable DHCP on the wireless link
    useDHCP = lib.mkDefault true;
    enableIPv6 = false;
  };

  hardware = {
    cpu.intel.updateMicrocode = true;
    graphics.enable = true;
    bluetooth.enable = true;
  };

  services.thermald.enable = true;

  powerManagement = {
    cpuFreqGovernor = lib.mkDefault "ondemand";
    powertop.enable = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
