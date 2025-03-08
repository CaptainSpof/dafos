{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) enabled disabled;
in
{
  imports = [ ./hardware.nix ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # we don't need no education
  documentation.man.generateCaches = false;

  # disable sleep
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  dafos = {
    archetypes = {
      workstation = enabled;
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

    services = {
      audiobookshelf = enabled;
      home-assistant = enabled;
      mealie = enabled;
      # tandoor = enabled;
      syncthing = enabled;
      printing = disabled;
    };

    suites = {
      desktop = enabled;
      yahrr = enabled;
      common = disabled;
      common-slim = enabled;
    };

    system = {
      kanata = enabled;

      networking = {
        enable = true;
        optimizeTcp = true;
      };
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Can't touch this 🔨
}
