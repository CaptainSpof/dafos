{
  config,
  lib,
  namespace,
  pkgs,
  inputs,
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
        colorScheme = "DankMatugenDark";
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
        # Make Dolphin follow the global color scheme. Under the qt6ct platform
        # theme (vs full Plasma), KColorSchemeManager doesn't see a "system"
        # scheme, so without this Dolphin falls back to its light default while
        # other KDE apps stay dark. "*" is KDE's "follow system scheme" sentinel.
        dolphinrc.UiSettings.ColorScheme = "*";
      };
    };

    qt = {
      enable = true;
      style.package = [
        inputs.darkly.packages.${pkgs.stdenv.hostPlatform.system}.darkly-qt6
      ];
      # platformTheme.name = "kde6";
    };

    home.sessionVariables = {
      QT_QPA_PLATFORMTHEME = "qt6ct";
      QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    };

    home.packages = with pkgs; [
      dafos.kde-warm-eyes
      dafos.leaf-kde
      dafos.plasma-applet-netspeed-widget
      gruvbox-gtk-theme
      kde-gruvbox
      papirus-icon-theme
      # Platform theme targeted by QT_QPA_PLATFORMTHEME below. Owned here so
      # Plasma works even when the niri module (which also installs it) is off.
      kdePackages.qt6ct
    ];
  };
}
