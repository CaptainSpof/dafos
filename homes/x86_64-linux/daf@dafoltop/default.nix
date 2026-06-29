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
      grimmory = enabled;
      calibre = enabled;
      donetick = enabled;
      espanso = mkForce disabled;
      glance = enabled;
      it-tools = enabled;
      lldap = enabled;
      norish = enabled;
      papra = enabled;
      reactive-resume = enabled;
      shelfmark = enabled;
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
