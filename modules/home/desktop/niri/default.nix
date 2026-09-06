{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf types optionalString;
  inherit (lib.${namespace}) mkBoolOpt mkOpt enabled;

  cfg = config.${namespace}.desktop.niri;
  firefox-pkg = config.${namespace}.programs.graphical.browsers.firefox.package;
in
{
  options.${namespace}.desktop.niri = {
    enable = mkBoolOpt true "Whether or not to use niri as the desktop environment.";
    screencastOutput = mkOpt (types.nullOr types.str) null ''
      Output the wlr ScreenCast portal captures without prompting (e.g. "DP-2").
      Headless selection matters for Steam Remote Play, where nobody is at the
      desk to answer a chooser dialog. null falls back to the first output.
    '';
  };

  config = mkIf cfg.enable {

    services.mpris-proxy.enable = true;

    dafos.system.gtkHmGuard = enabled;

    programs = {
      niri = {
        enable = true;
        package = pkgs.niri-unstable;

        settings = {
          debug = {
            honor-xdg-activation-with-invalid-serial = { };
          };

          prefer-no-csd = true;

          blur = {
            passes = 3;
            offset = 4.0;
          };

          # Output (monitor) configuration is host-specific and lives in each
          # host's home (homes/<host>/default.nix: programs.niri.settings.outputs)
          # since the physical panels differ per machine.

          input = {
            focus-follows-mouse.enable = true;
            focus-follows-mouse.max-scroll-amount = "55%";
          };

          layout = {
            gaps = 24;
            struts = {
              left = 64;
              right = 64;
            };

            always-center-single-column = true;
            empty-workspace-above-first = true;

            focus-ring.enable = true;
            border.enable = true;

            shadow.enable = true;

            default-column-display = "tabbed";

            tab-indicator = {
              gaps-between-tabs = 10;

              hide-when-single-tab = true;
              place-within-column = true;
            };
          };

          screenshot-path = "~/Pictures/Screenshots/%Y-%m-%dT%H:%M:%S.png";
          hotkey-overlay.skip-at-startup = true;

          binds = import ./binds.nix { inherit config lib firefox-pkg; };

          layer-rules = import ./layer-rules.nix;

          window-rules = import ./window-rules.nix;
        };
      };
    };

    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = [
        pkgs.kdePackages.xdg-desktop-portal-kde
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-wlr
        # RemoteDesktop backend only (see config.common below); deliberately
        # kept out of configPackages so its own portals.conf — which claims
        # ScreenCast, Screenshot, Settings and more — can't take over the
        # interfaces the kde/gnome/wlr backends already serve here.
        pkgs.xdg-desktop-portal-luminous
      ];
      configPackages = [
        pkgs.kdePackages.xdg-desktop-portal-kde
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-wlr
      ];
      config.common = {
        default = "kde";
        # The kde Settings backend can't recompute light/dark outside a full
        # Plasma session (no kded to signal it), so it always reports "light"
        # under Niri — breaking prefers-color-scheme for GTK/Firefox/Electron.
        # Route just the Settings interface to the gtk backend, which follows
        # the org.gnome.desktop.interface color-scheme gsetting (prefer-dark).
        "org.freedesktop.impl.portal.Settings" = "gtk";
        # ScreenCast must go to the wlr backend (via niri's zwlr_screencopy),
        # NOT gnome: niri's own Mutter.ScreenCast pipewire streams are
        # DMABUF-only, and Steam's bundled libgbm can't create a GBM device
        # on a modern-mesa host (its dri backend discovery predates the
        # mesa 25.1 dri_gbm.so split), so Steam can't negotiate any format
        # ("no more input formats") and Remote Play streams black frames.
        # xdg-desktop-portal-wlr serves plain SHM buffers, which Steam
        # consumes fine.
        "org.freedesktop.impl.portal.ScreenCast" = "wlr";
        "org.freedesktop.impl.portal.Screenshot" = "gnome";
        # KDE Connect's remote input (and anything else asking for
        # RemoteDesktop) has no backend under Niri: xdg-desktop-portal-kde
        # only registers the interface when it can reach KWin, -gnome when it
        # can reach mutter, and -wlr never implemented it — so kdeconnectd
        # got "No such interface org.freedesktop.impl.portal.RemoteDesktop"
        # and then spammed NotifyPointerMotion at an invalid session path.
        # luminous injects through zwlr_virtual_pointer_v1 and
        # zwp_virtual_keyboard_v1, both of which Niri implements.
        "org.freedesktop.impl.portal.RemoteDesktop" = "luminous";
      };
    };

    # chooser_type=none: pick the output headlessly instead of popping a
    # chooser dialog on the desk — Remote Play sessions start with nobody
    # there to answer it.
    xdg.configFile."xdg-desktop-portal-wlr/config".text = ''
      [screencast]
      chooser_type=none
      ${optionalString (cfg.screencastOutput != null) "output_name=${cfg.screencastOutput}"}
      max_fps=60
    '';

    gtk = {
      enable = true;
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      gtk4.theme = null;
    };

    home.packages = with pkgs; [
      adw-gtk3
      fuzzel
      grim
      kanagawa-icon-theme
      kdotool
      libnotify
      nirius
      nwg-look
      playerctl
      satty
      slurp
      wdisplays
      wl-mirror
      xwayland-satellite
      yazi

      kdePackages.qt6ct
      kdePackages.sonnet
    ];
  };
}
