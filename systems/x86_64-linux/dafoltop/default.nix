{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) enabled disabled;
  inherit (lib) mkForce;
in
  {
    imports = [ ./hardware.nix ];

    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

    # we don't need no education
    documentation.enable = false;
    documentation.man.generateCaches = false;
    documentation.nixos.enable = false;

    # disable sleep
    systemd.targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };

    system.activationScripts.setHomePermissions = ''
      chmod g+rx /home/daf
      # chgrp yahrr /home/daf
    '';

    dafos = {
      archetypes = {
        workstation = enabled;
      };

      apps = {
        qbittorrent = lib.mkForce disabled;
      };

      desktop.niri.enable = mkForce false;

      display-managers = {
        enable = true;
        defaultSession = "plasma";
        autoLogin = {
          enable = true;
          user = config.${namespace}.user.name;
        };
      };

      services = {
        audiobookshelf = disabled;
        bar-assistant = disabled;
        paperless = disabled;
        # caddy = enabled;
        # calibre = enabled;
        # calibre-web-automated = enabled;
        # karakeep = enabled;
        glance = disabled;
        home-assistant = enabled;
        immich = enabled;
        # immich-frame = enabled;
        immich-kiosk = enabled;
        # wishlist = enabled;
        # it-tools = enabled;
        # mealie = enabled;
        # tandoor = enabled;
        printing = disabled;
        # stirling-pdf = enabled;
        # send = enabled;
        # syncthing = enabled;
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
