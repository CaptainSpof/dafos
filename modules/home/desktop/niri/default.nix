{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf mkForce;
  inherit (lib.${namespace}) mkBoolOpt;
  inherit (config.${namespace}.programs.graphical.launchers) vicinae;

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

          binds =
            with config.lib.niri.actions;
            let
              dms-ipc = spawn "dms" "ipc";
            in
            mkForce {
              "Mod+Q" = {
                repeat = false;
                action = close-window;
              };
              "Mod+MouseMiddle".action = close-window;
              "Mod+Shift+Slash".action = show-hotkey-overlay;
              "Mod+W".action = spawn "${toString firefox-pkg.meta.mainProgram}";
              "Mod+D".action = spawn "wezterm";
              "Mod+M".action = spawn "dolphin";
              # "Mod+E".action = spawn "emacsclient";
              #   "Mod+Space" = mkIf vicinae.enable {
              #   repeat = false;
              #   action = spawn "vicinae" "toggle";
              # };
              # "Mod+V" = {
              #   repeat = false;
              #   action = spawn "vicinae" "vicinae://extensions/vicinae/clipboard/history";
              # };
              "Mod+Space" = {
                action = dms-ipc "spotlight" "toggle";
                hotkey-overlay.title = "Toggle Application Launcher";
              };
              "Mod+V" = {
                action = dms-ipc "clipboard" "toggle";
                hotkey-overlay.title = "Toggle Clipboard Manager";
              };
              "Mod+N" = {
                action = dms-ipc "notifications" "toggle";
                hotkey-overlay.title = "Toggle Notification Center";
              };
              "Mod+P" = {
                action = dms-ipc "notepad" "toggle";
                hotkey-overlay.title = "Toggle Notepad";
              };
              "Mod+X" = {
                action = dms-ipc "powermenu" "toggle";
                hotkey-overlay.title = "Toggle Power Menu";
              };
              "Mod+Delete" = {
                action = dms-ipc "processlist" "toggle";
                hotkey-overlay.title = "Toggle Process List";
              };
              "Mod+Z".action = toggle-overview;

              "Mod+BackSpace" = {
                repeat = false;
                action = dms-ipc "lock" "lock";
              };

              "Mod+XF86AudioMute".action = dms-ipc "notifications" "toggleDoNotDisturb";

              "Mod+Return".action = maximize-window-to-edges;
              "Mod+Shift+Return".action = fullscreen-window;
              "Mod+F".action = toggle-window-floating;
              "Mod+Shift+F".action = switch-focus-between-floating-and-tiling;

              "Mod+O".action = switch-preset-column-width;

              "Mod+R".action = focus-window-or-workspace-down;
              "Mod+T".action = focus-window-or-workspace-up;
              "Mod+L".action = focus-column-left;
              "Mod+I".action = focus-column-right;

              "Mod+Shift+R".action = move-window-down-or-to-workspace-down;
              "Mod+Shift+T".action = move-window-up-or-to-workspace-up;
              "Mod+Shift+L".action = move-column-left-or-to-monitor-left;
              "Mod+Shift+I".action = move-column-right-or-to-monitor-right;

              "Mod+Comma".action = set-column-width "+15%";
              "Mod+Mod5+R".action = set-column-width "-15%";
              "Mod+G".action = set-column-width "-15%";
              "Mod+Mod5+T".action = set-column-width "+15%";

              "Mod+Alt+R".action = consume-window-into-column;
              "Mod+Alt+T".action = expel-window-from-column;

              "Mod+S".action.toggle-column-tabbed-display = { };

              # Center
              "Mod+C".action.center-column = { };
              "Mod+Alt+C".action.center-visible-columns = { };

              "Print".action.screenshot = [ ];
              "Ctrl+Print".action.screenshot-screen = [ ];
              "Alt+Print".action.screenshot-window = [ ];

              "XF86MonBrightnessUp" = {
                allow-when-locked = true;
                action = dms-ipc "brightness" "increment" "5" "";
              };
              "XF86MonBrightnessDown" = {
                allow-when-locked = true;
                action = dms-ipc "brightness" "decrement" "5" "";
              };

              "XF86AudioRaiseVolume" = {
                allow-when-locked = true;
                action = dms-ipc "audio" "increment" "5";
              };
              "XF86AudioLowerVolume" = {
                allow-when-locked = true;
                action = dms-ipc "audio" "decrement" "5";
              };
              "XF86AudioMute" = {
                allow-when-locked = true;
                action = dms-ipc "audio" "mute";
              };
              "XF86AudioMicMute" = {
                allow-when-locked = true;
                action = dms-ipc "audio" "micmute";
              };
            };

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
                { app-id = "^org\.wezfurlong\.wezterm$"; }
                { app-id = "^emacs$"; }
              ];
              default-column-width = {
                proportion = 0.75;
              };
              default-window-height = { };
            }
            {
              matches = [
                { app-id = "^org\.gnome\.Loupe"; }
                { app-id = "^org\.gnome\.Nautilus"; }
                { app-id = "^org\.gnome\.Papers"; }
                { app-id = "^org\.gnome\.Calculator"; }
                { app-id = "^app\.drey\.Warp"; }
                { app-id = "^org\.gnome\.NautilusPreviewer$"; }
                { app-id = "^org\.gnome\.Adwaita1\.Demo$"; }
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
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-wlr
      ];
      configPackages = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-wlr
      ];
      config.common.default = "gtk";
    };

    home.packages = with pkgs; [
      adw-gtk3
      nwg-look
      fuzzel
      kanagawa-gtk-theme
      kanagawa-icon-theme
      libnotify
      nirius
      wdisplays
      wl-mirror
      xwayland-satellite
      yazi

      kdePackages.qt6ct
      kdePackages.sonnet
    ];
  };
}
