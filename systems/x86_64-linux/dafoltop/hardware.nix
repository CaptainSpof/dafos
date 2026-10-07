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
    "file_mode=0775"
    "dir_mode=0775"
    "vers=3"
    # Freebox doesn't report stable server inode numbers; silences the
    # "Autodisabling server inode numbers"/"Hardlinks will not be recognized" warnings.
    "noserverino"
    "nounix"
    "x-systemd.automount"
    "noauto"
    "x-systemd.requires=wait-freebox-available.service"
    "x-systemd.after=wait-freebox-available.service"
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
    kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [
      "tcp_bbr"
      "uhid"
    ];
    # The laptop is on AC 24/7; USB autosuspend dropping the mounted media
    # disk mid-scrub or mid-import is a real failure mode, not a theoretical
    # one, for a bus-powered-adjacent (dock-powered but bridge-negotiated)
    # device that's supposed to stay live.
    kernelParams = [ "usbcore.autosuspend=-1" ];

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
    # "btrfs" is for the USB-attached media disk (disko.nix); its root/nix are
    # ext4, so btrfs-progs was never on this host before.
    supportedFilesystems = [
      "cifs"
      "btrfs"
    ];
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

    "/mnt/yahrr" = {
      device = "//${freeboxHostname}/Freebox/yahrr";
      fsType = "cifs";
      options = freeboxCifsOptions;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/livres 0775 calibre calibre - -"
    # Book libraries (calibre, grimmory, bookorbit) that live on the root disk.
    # They existed only as container bind-mount sources, so a reinstall would
    # have produced empty libraries. Owners match what is on disk today.
    "d /mnt/calibre 0755 daf users - -"
    "d /mnt/grimmory 0755 daf root - -"
    "d /mnt/bookorbit 0755 daf root - -"
  ];

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

    # The Freebox hands 192.168.0.10 to this MAC, and blocky binds to that address
    # (dafbox uses it as its DNS server). The lease is keyed on the USB ethernet
    # adapter burned-in MAC, so a replacement adapter would otherwise come up with
    # a new address and take DNS down. Clone the old MAC onto whichever ethernet
    # device NetworkManager brings up. Wi-Fi has its own setting, unaffected.
    networkmanager.ethernet.macAddress = "00:e0:4c:36:02:d2";

    # The LAN link as a declared profile (it used to be NetworkManager's
    # automatic "Wired connection 1"), for one addition: `~daftdaf.dev` as a
    # routing domain, so resolved asks only the link's blocky servers for
    # *.daftdaf.dev instead of racing them against the public resolvers in the
    # global list (services moved to dafpi then resolved to the Freebox, i.e.
    # back to this host). Every other name still goes out as before, and the
    # rootless containers' DNS (aardvark -> the host's upstream list) is
    # untouched. NetworkManager does not move a connected device to a new
    # profile, so this takes over at the next reconnect or reboot.
    networkmanager.ensureProfiles.profiles.lan = {
      connection = {
        id = "lan";
        type = "ethernet";
        interface-name = "enp0s20f0u1u2";
        autoconnect-priority = 10;
      };
      ethernet = { };
      ipv4 = {
        method = "auto";
        dns-search = "~daftdaf.dev";
      };
      ipv6 = {
        method = "auto";
        dns-search = "~daftdaf.dev";
      };
    };
  };

  hardware = {
    cpu.intel.updateMicrocode = true;
    graphics.enable = true;
    bluetooth.enable = true;
  };

  services.thermald.enable = true;

  # The USB media disk (disko.nix) is a single used drive with no redundancy;
  # a monthly scrub is the only thing that will notice it starting to rot.
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/mnt/data" ];
    interval = "monthly";
  };

  powerManagement = {
    cpuFreqGovernor = lib.mkDefault "ondemand";
    powertop.enable = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
