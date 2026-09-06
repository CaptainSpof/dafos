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
          ssh = enabled;
        };
      };
    };

    services = {
      sops.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/daf@dafoltop" ];

      authelia = enabled;
      bar-assistant = enabled;
      bookorbit = enabled;
      grimmory = enabled;
      calibre = enabled;
      donetick = enabled;
      espanso = mkForce disabled;
      glance = enabled;
      immich-kiosk = enabled;
      it-tools = enabled;
      kaneo = enabled;
      lldap = enabled;
      norish = {
        enable = true;
        # Points at dafoltop's local ollama (see dafos.services.ollama there).
        ai = enabled;
      };
      papra = enabled;
      reactive-resume = enabled;
      shelfmark = enabled;
      sparky-fitness = enabled;
      streaming = enabled;
      traefik = enabled;
    };

    suites = {
      common = enabled;
      desktop = enabled;
      video = disabled;
    };
  };
}
