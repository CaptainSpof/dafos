{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt enabled disabled;

  cfg = config.${namespace}.suites.desktop;
in
{
  options.${namespace}.suites.desktop = {
    enable = mkBoolOpt false "Whether or not to enable common desktop configuration.";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      kdePackages.filelight
      gparted
    ];

    dafos = {
      desktop = {
        gnome = disabled;
        plasma = enabled;
        niri = enabled;
      };
    };
  };
}
