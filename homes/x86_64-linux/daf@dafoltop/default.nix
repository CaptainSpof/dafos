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
      glance = enabled;
      it-tools = enabled;
      # karakeep = enabled;
      lldap = enabled;
      norish = enabled;
      papra = enabled;
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
