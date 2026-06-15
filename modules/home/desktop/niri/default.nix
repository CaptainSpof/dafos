{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.desktop.niri;
  firefox-pkg = config.${namespace}.programs.graphical.browsers.firefox.package;
in
{
  options.${namespace}.desktop.niri = {
    enable = mkBoolOpt true "Whether or not to use niri as the desktop environment.";
  };

  config = mkIf cfg.enable {

    services.mpris-proxy.enable = true;

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

            # fog of war
            focus-ring = {
              enable = true;
              width = 1.5;
              active.gradient = {
                from = "red";
                to = "orange";
                angle = 45;
                in' = "oklch shorter hue";
              };
            };

            border = {
              width = 1;
              active.gradient = {
                from = "red";
                to = "orange";
                in' = "oklch shorter hue";
              };
            };

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

          layer-rules = [
            {
              matches = [
                { namespace = "^noctalia-overview*"; }
                { namespace = "dms:blurwallpaper"; }
              ];
              place-within-backdrop = true;
            }
          ];

          window-rules = [
            {
              draw-border-with-background = false;
              geometry-corner-radius =
                let
                  r = 8.0;
                in
                {
                  top-left = r;
                  top-right = r;
                  bottom-left = r;
                  bottom-right = r;
                };
              clip-to-geometry = true;
            }
            {
              matches = [
                { app-id = "^org\\.wezfurlong\\.wezterm$"; }
                { app-id = "^emacs$"; }
              ];
              # Blur whatever shows through these (translucent) terminals.
              background-effect = {
                blur = true;
              };
              default-column-width = {
                proportion = 0.75;
              };
              default-window-height = { };
            }
            {
              matches = [
                { app-id = "^org\\.gnome\\.Loupe"; }
                { app-id = "^org\\.gnome\\.Nautilus"; }
                { app-id = "^org\\.gnome\\.Papers"; }
                { app-id = "^org\\.gnome\\.Calculator"; }
                { app-id = "^app\\.drey\\.Warp"; }
                { app-id = "^org\\.gnome\\.NautilusPreviewer$"; }
                { app-id = "^org\\.gnome\\.Adwaita1\\.Demo$"; }
              ];
              tiled-state = false;
              default-column-width = { };
              default-window-height = { };
            }
          ];
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
      ];
      configPackages = [
        pkgs.kdePackages.xdg-desktop-portal-kde
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-wlr
      ];
      config.common = {
        default = "kde";
      };
    };

    # Pin a dark GTK theme.
    gtk = {
      enable = true;
      theme = {
        name = "Gruvbox-Dark";
        package = pkgs.gruvbox-gtk-theme;
      };
      gtk4.theme = null;
    };

    home.packages = with pkgs; [
      adw-gtk3
      fuzzel
      grim
      kanagawa-gtk-theme
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
