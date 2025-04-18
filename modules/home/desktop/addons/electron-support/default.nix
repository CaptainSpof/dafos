{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.desktop.addons.electron-support;
in
{
  options.${namespace}.desktop.addons.electron-support = {
    enable = mkBoolOpt false "Whether to enable electron support in the desktop environment.";
  };

  config = mkIf cfg.enable {

    home.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    xdg.configFile."electron-flags.conf".source = ./electron-flags.conf;
  };
}
