{
  config,
  lib,
  namespace,
  pkgs,
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
    home.packages = with pkgs; [
      # smile # emoji picker
      # kdePackages.arianna # ebook reader
      dconf-editor
      gsettings-desktop-schemas
      gsettings-qt
    ];

    dafos = {
      desktop = {
        niri = disabled;
        noctalia-shell = disabled;
        dms = disabled;
        plasma = {
          enable = true;
          config = enabled;
          desktop = enabled;
          kwin = enabled;
          panels = enabled;
          shortcuts = enabled;
          theme = enabled;
        };
        addons = {
          wallpapers = disabled;
        };
      };
      programs = {
        graphical = {
          launchers.vicinae = enabled;
        };
      };
    };
  };
}
