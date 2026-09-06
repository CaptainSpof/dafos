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
          UiSettings.ColorScheme = "*";
        };

        kcminputrc.Mouse.cursorTheme = "breeze_cursors";

        # kded6 still opens its module config as *kded5rc* (KConfig derives the
        # name from the app name, which upstream left at "kded5" for config
        # compatibility) — the obvious-looking "kdedrc"/"kded6rc" are read by
        # nobody, so writing there silently does nothing.
        #
        # gtkconfig must stay off: any KDE/KIO app (gwenview, Dolphin, Ark, ...)
        # D-Bus-activates kded6, whose gtkconfig module then rewrites
        # ~/.gtkrc-2.0, ~/.config/xsettingsd/xsettingsd.conf and — the fatal one
        # — ~/.config/gtk-3.0/{gtk,colors}.css. kde-gtk-config's
        # libcolorreload-gtk-module.so puts a GFileMonitor on colors.css, and
        # once GTK has dlclosed that module the monitor is still armed, so the
        # rewrite dispatches into unmapped memory and SIGSEGVs *every* GTK app
        # at once (Firefox, emacs-pgtk, xdg-desktop-portal-gtk). It also
        # clobbers the matugen-generated gtk.css that DMS owns here.
        kded5rc."Module-gtkconfig".autoload = false;

        # Darkly widget-style settings (the "Application Style -> Darkly ->
        # Configure" page). Captured from ~/.config/darklyrc; plasma-manager
        # re-asserts them on activation but leaves them writable so the KCM
        # still works.
        darklyrc = {
          Common = {
            ScrollBarTransient = true;
            ShadowSize = "ShadowMedium";
          };
          Style = {
            DolphinSidebarOpacity = 80;
            DolphinViewOpacity = 90;
            MenuBarOpacity = 80;
            MenuItemDrawStrongFocus = false;
            MenuOpacity = 80;
            RoundedRubberBandFrame = false;
            SidePanelDrawFrame = true;
            TabBarOpacity = 80;
            ToolBarOpacity = 80;
          };
        };
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
      # Kirigami / QtQuick Controls apps (skanpage, etc.) default to the light
      # "Basic" style outside Plasma. Force the KDE style so they follow the
      # color scheme (provided by qqc2-desktop-style, in home.packages below).
      QT_QUICK_CONTROLS_STYLE = "org.kde.desktop";
    };

    systemd.user.paths.dms-kde-colorscheme = {
      Unit.Description = "Watch for DMS colour scheme regeneration";
      Path = {
        PathChanged = "${home}/.local/share/color-schemes/DankMatugen.colors";
        Unit = "dms-kde-colorscheme.service";
      };
      Install.WantedBy = [ "paths.target" ];
    };

    systemd.user.services.dms-kde-colorscheme = {
      Unit.Description = "Apply the DMS colour scheme to kdeglobals";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.kdePackages.plasma-workspace}/bin/plasma-apply-colorscheme DankMatugen";
      };
    };

    home.packages = with pkgs; [
      dafos.kde-warm-eyes
      dafos.leaf-kde
      dafos.plasma-applet-netspeed-widget
      kdePackages.qqc2-desktop-style # org.kde.desktop QtQuick Controls style
      kde-gruvbox
      papirus-icon-theme
      # Platform theme targeted by QT_QPA_PLATFORMTHEME below. Owned here so
      # Plasma works even when the niri module (which also installs it) is off.
      kdePackages.qt6ct
    ];
  };
}
