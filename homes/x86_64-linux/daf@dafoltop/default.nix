{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) enabled disabled;
  inherit (lib) mkForce;
in
{
  dafos = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    desktop = {
      niri.enable = mkForce false;
      dms.enable = mkForce false;
      dankcalendar.enable = mkForce false;

      plasma = {
        theme.wallpaper = disabled;
        config.screenlocker = disabled;
      };

      addons = {
        wallpapers.enable = mkForce false;
      };
    };

    programs = {
      # Unattended RustDesk target: controllable over the tailnet via direct IP.
      rustdesk = disabled;
      graphical = {
        launchers.vicinae = mkForce disabled;
      };

      terminal = {
        tools = {
          podman-tui = enabled;
          ssh = enabled;
        };
      };
    };

    services = {
      sops.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/daf@dafoltop.pem" ];

      authelia = enabled;
      # Serve the OIDC clients and lldap groups of the apps running on dafpi
      # (flake-modules/services/authelia-peers.nix).
      authelia-peers.peers = [ "dafpi" ];
      backup-dumps = enabled;
      bar-assistant = enabled;
      bookorbit = enabled;
      grimmory = enabled;
      calibre = enabled;
      crowdsec = enabled;
      socket-proxy = enabled;
      # Live container logs + crash alerts, admins only (flake-modules/services/dozzle.nix).
      dozzle = enabled;
      # Push containers / storage / failed-unit state to gatus on dafpi every
      # 5 min (flake-modules/services/health-push.nix).
      health-push = {
        enable = true;
        mounts = [
          "/mnt/data"
          "/mnt/backup"
        ];
        disks = [
          "/"
          "/home"
          "/mnt/data"
          "/mnt/backup"
        ];
      };
      donetick = enabled;
      espanso = mkForce disabled;
      # gatus moved to dafpi (flake-modules/services/gatus.nix): it watches
      # this box from outside now.
      glance = {
        enable = true;
        engine = "dynacat";
      };
      immich-kiosk = enabled;
      # it-tools moved to dafpi (flake-modules/hosts/dafpi).
      kaneo = enabled;
      kitchenowl = enabled;
      lldap = enabled;
      norish = {
        enable = true;
        # Points at dafoltop's local ollama (see dafos.services.ollama there).
        ai = enabled;
      };
      papra = enabled;
      reactive-resume = enabled;
      securo = {
        enable = true;
        enableBankingAppId = "2d512d1c-a7f8-45d3-9a17-7b2c5e1f97ae";
      };
      shelfmark = enabled;
      sparky-fitness = enabled;
      spliit = enabled;
      streaming = enabled;
      traefik = {
        enable = true;
        # Immich, Home Assistant, the zone configurator and zigbee2mqtt run
        # natively on this host.
        nativeRouters.enable = true;
      };
    };

    suites = {
      common = enabled;
      desktop = enabled;
      video = disabled;
    };
  };
}
