{ config, lib, namespace, ... }:

with lib;
with lib.${namespace};
{
  imports = [ ./hardware.nix ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  dafos = {
    archetypes = {
      workstation = enabled;
      gaming = enabled;
    };

    apps = { qbittorrent = enabled; };

    desktop = {
      plasma = {
        autoLoginUser = config.${namespace}.user.name;
        config = {
          virtualDesktopsNames = [
            "Mail"
            "Video"
            "Other"
            "Stuff"
            "Yes"
          ];
        };
        panels = {
          leftPanel.launchers = [
            "applications:org.kde.dolphin.desktop"
            "applications:firefox-beta.desktop"
            "applications:kitty.desktop"
            "applications:emacsclient.desktop"
            "applications:steam.desktop"
          ];
        };
      };
    };

    hardware = {
      cpu.amd = enabled;
      gpu.amd = enabled;
    };

    security = { gpg = mkForce disabled; };

    services.syncthing = enabled;

    suites = {
      desktop = enabled;
      development = enabled;
    };

    system = { kanata = enabled; };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Can't touch this 🔨
}
