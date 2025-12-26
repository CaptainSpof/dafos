{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;
  inherit (config.${namespace}.user) home;
  inherit (config.${namespace}.user.font) ui mono;

  cfg = config.${namespace}.desktop.plasma.theme;

  defaultFont = {
    family = ui;
    pointSize = 10;
  };
in
{
  options.${namespace}.desktop.plasma.theme = {
    enable = mkBoolOpt false "Whether or not to configure plasma theme.";
    wallpaper.enable = mkBoolOpt true "Whether or not to enable custom wallpapers.";
  };

  config = mkIf cfg.enable {
    programs.plasma = {
      fonts = {
        general = defaultFont;
        fixedWidth = defaultFont // {
          family = mono;
        };
        small = defaultFont // {
          pointSize = 8;
        };
        toolbar = defaultFont;
        menu = defaultFont;
        windowTitle = defaultFont;
      };

      workspace = {
        clickItemTo = "open";
        colorScheme = "WarmEyes";
        cursor.theme = "breeze_cursors";
        soundTheme = "ocean";
        tooltipDelay = 5;
        theme = "breeze-dark";
        iconTheme = "Papirus-Dark";
        wallpaperSlideShow = mkIf cfg.wallpaper.enable {
          path = "${home}/Pictures/Wallpapers/";
          interval = 600;
        };
        wallpaperFillMode = "stretch";
        windowDecorations = {
          library = "org.kde.darkly";
          theme = "Darkly";
        };
      };

      configFile = {
        kdeglobals = {
          KDE.widgetStyle = "Darkly";
          General.AccentColorFromWallpaper = true;
        };
      };
    };
  };
}
