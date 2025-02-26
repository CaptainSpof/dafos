{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) enabled;
in
{
  imports = [ ./hardware.nix ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  dafos = {
    archetypes = {
      workstation = enabled;
      gaming = enabled;
    };

    apps = {
      qbittorrent = enabled;
    };

    display-managers = {
      enable = true;
      autoLogin = {
        enable = true;
        user = config.${namespace}.user.name;
      };
    };

    hardware = {
      cpu.amd = enabled;
      gpu.amd.enable = true;
    };

    security = {
      sudo-rs = enabled;
    };

    services.syncthing = enabled;

    suites = {
      desktop = enabled;
      development = {
        enable = true;
        podman = enabled;
      };
    };

    system = {
      kanata = {
        enable = true;
        chordTimeout = 25;
      };

      networking = {
        enable = true;
        optimizeTcp = true;
      };
    };
  };

  systemd = {
    network.networks = {
      # wired interfaces e.g. ethernet
      "30-network-defaults-wired" = {
        matchConfig.Name = "en* | eth* | usb*";
        networkConfig = {
          DHCP = "ipv4";
          MulticastDNS = true;
        };
      };
    };

    services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Can't touch this 🔨
}
