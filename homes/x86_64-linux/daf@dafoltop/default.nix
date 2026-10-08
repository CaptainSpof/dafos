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
      # donetick moved to dafpi (flake-modules/hosts/dafpi).
      espanso = mkForce disabled;
      # gatus moved to dafpi (flake-modules/services/gatus.nix): it watches
      # this box from outside now.
      glance = {
        enable = true;
        engine = "dynacat";
      };
      immich-kiosk = enabled;
      # it-tools moved to dafpi (flake-modules/hosts/dafpi).
      # kaneo moved to dafpi (flake-modules/hosts/dafpi).
      # kitchenowl moved to dafpi (flake-modules/hosts/dafpi).
      lldap = enabled;
      norish = {
        enable = true;
        # Points at dafoltop's local ollama (see dafos.services.ollama there).
        ai = enabled;
      };
      # papra moved to dafpi (flake-modules/hosts/dafpi).
      reactive-resume = enabled;
      # securo moved to dafpi (flake-modules/hosts/dafpi).
      shelfmark = enabled;
      # sparky-fitness moved to dafpi (flake-modules/hosts/dafpi).
      spliit = enabled;
      streaming = enabled;
      traefik = {
        enable = true;
        # Immich, Home Assistant, the zone configurator and zigbee2mqtt run
        # natively on this host.
        nativeRouters.enable = true;
        # Relay what dafpi's own Traefik serves (public: the Freebox forwards
        # here; tailnet clients outside the LAN too).
        peers.dafpi = "192.168.0.15";
      };
    };

    suites = {
      common = enabled;
      desktop = enabled;
      video = disabled;
    };
  };
}
