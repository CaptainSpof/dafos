{
  lib,
  config,
  namespace,
  pkgs,
  inputs,
  ...
}:

let
  inherit (lib.${namespace}) enabled disabled;

  dmsParts = config.${namespace}.desktop.dms.bar.parts;
in
{
  dafos = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    desktop = {
      # daftop's bars. The shared vocabulary is in
      # modules/home/desktop/dms/bar.nix; everything here is where this laptop
      # disagrees with it.
      #
      # Neither bar is pinned to a named output: daftop docks to different
      # panels (its niri outputs below currently disable eDP-1 in favour of an
      # external HDMI-A-1), so an output name would just make a bar disappear.
      dms.bar = {
        configs = [
          # Top bar as a DMS island — the pill carries media, the clock, the
          # weather and the notification badge, and expands to the full widget
          # rows on hover.
          (
            dmsParts.mainBar
            // dmsParts.islandStyle
            // {
              transparency = 0.8;

              leftWidgets = [
                "launcherButton"
                {
                  id = "workspaceSwitcher";
                  enabled = true;
                  # No follow-focus here: on a single-panel laptop the focus
                  # already moves with the workspace.
                  workspaceFollowFocus = false;
                  workspaceFocusedBorderColor = "surfaceText";
                }
                {
                  id = "focusedWindow";
                  enabled = true;
                  focusedWindowCompactMode = true;
                  # Title only — the icon repeats what the dock already shows.
                  focusedWindowShowIcon = false;
                }
                # (no dankPomodoroTimer — it lives on the side bar here)
              ];

              rightWidgets = [
                {
                  id = "systemTray";
                  enabled = true;
                }
                {
                  id = "network_speed_monitor";
                  enabled = true;
                }
                {
                  id = "cpuUsage";
                  enabled = true;
                  minimumWidth = false;
                }
                {
                  id = "memUsage";
                  enabled = true;
                }
                {
                  # The island's `notifications` group carries the badge.
                  id = "notificationButton";
                  enabled = false;
                }
                {
                  id = "battery";
                  enabled = true;
                  batteryStyle = "outline";
                }
                {
                  id = "controlCenterButton";
                  enabled = true;
                  showIdleInhibitorIcon = true;
                  showDoNotDisturbIcon = true;
                  # VPN and audio first; the rest is DMS's own order.
                  controlCenterGroupOrder = [
                    "vpn"
                    "audio"
                    "bluetooth"
                    "network"
                    "microphone"
                    "brightness"
                    "battery"
                    "printer"
                    "screenSharing"
                    "idleInhibitor"
                    "doNotDisturb"
                  ];
                }
                {
                  id = "privacyIndicator";
                  enabled = true;
                }
              ];
            }
          )

          # The utility bar as the fleet defines it; only the panel it lands on
          # is daftop's business.
          (
            dmsParts.sideBar
            // {
              screenPreferences = [ "all" ];
            }
          )
        ];

        # Same tiles as the fleet default, re-laid out for a laptop: the
        # toggles this machine reaches for get a half row each, and a battery
        # tile is worth the quarter row it costs.
        controlCenterWidgets = [
          {
            id = "volumeSlider";
            enabled = true;
            w = 4;
            h = 1;
          }
          {
            id = "brightnessSlider";
            enabled = true;
            # DDC over the external panel's i2c bus. This is a bus *number*,
            # so it can move when the docking situation changes — re-read it
            # from the control centre's brightness picker if it stops working.
            deviceName = "ddc:i2c-13";
            w = 4;
            h = 1;
          }
          {
            id = "audioOutput";
            enabled = true;
            w = 4;
            h = 1;
          }
          {
            id = "audioInput";
            enabled = true;
            w = 4;
            h = 1;
          }
          {
            id = "wifi";
            enabled = true;
            w = 4;
            h = 1;
          }
          {
            id = "builtin_vpn";
            enabled = true;
            w = 4;
            h = 1;
          }
          {
            id = "bluetooth";
            enabled = true;
            w = 8;
            h = 1;
          }
          {
            id = "nightMode";
            enabled = true;
            w = 4;
            h = 1;
          }
          {
            id = "darkMode";
            enabled = true;
            w = 4;
            h = 1;
          }
          {
            id = "idleInhibitor";
            enabled = true;
            w = 4;
            h = 1;
          }
          {
            id = "doNotDisturb";
            enabled = true;
            w = 4;
            h = 1;
          }
          {
            id = "colorPicker";
            enabled = true;
            w = 2;
            h = 1;
          }
          {
            id = "plugin_dankKDEConnect";
            enabled = true;
            w = 4;
            h = 1;
          }
          {
            id = "battery";
            enabled = true;
            w = 2;
            h = 1;
          }
        ];

        dockConfigs = [
          (
            builtins.head dmsParts.dockConfigs
            // {
              transparency = 0.8;
              # No border: the island above already draws one edge, and a
              # second outline on a 14" panel is noise.
              borderEnabled = false;

              widgets = [
                {
                  id = "dock_launcher";
                  widgetId = "dockLauncher";
                  enabled = true;
                }
                {
                  id = "dock_apps";
                  widgetId = "appsDock";
                  enabled = true;
                  appsDockColorizeActive = true;
                  appsDockActiveColorMode = "primaryContainer";
                }
                {
                  id = "dock_trash";
                  widgetId = "dockTrash";
                  enabled = true;
                }
              ];
            }
          )
        ];
      };

      plasma = {
        touchScreen = false;
        themeSwitcher = false;
        desktop.digitalClock.position.horizontal = 1200;
      };
    };

    programs = {

      ai = {
        enable = true;
        claude.code = enabled;
        claude.desktop = enabled;
        antigravity.cli = enabled;
      };

      graphical = {
        browsers = {
          firefox = {
            enable = true;
            package = inputs.firefox.packages.${pkgs.stdenv.hostPlatform.system}.firefox-nightly-bin;
            # package = pkgs.firefox-beta;
            gpuAcceleration = true;
            hardwareDecoding = true;
            settings = {
              # "dom.ipc.processCount.webIsolated" = 9;
              # "dom.maxHardwareConcurrency" = 16;
              # "media.ffvpx.enabled" = false;
              "media.hardware-video-decoding.force-enabled" = true;
              "media.hardwaremediakeys.enabled" = true;
            };
          };
        };
        instant-messengers.teamspeak = disabled;
      };

      terminal = {
        emulators.wezterm.wayland.enable = true;
        tools = {
          ssh = enabled;
        };
      };
    };

    services.kanata-notify = enabled;

    services.sops = {
      enable = true;
      defaultSopsFile = lib.snowfall.fs.get-file "secrets/daftop/daf/default.yaml";
      sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/daf@daftop.pem" ];
    };

    system.xdg = enabled;

    suites = {
      common = enabled;
      desktop = enabled;

      development = {
        enable = true;
        aws = disabled;
        podman = enabled;
      };

      games = enabled;

      graphics = {
        enable = true;
        drawing = enabled;
        graphics3d = enabled;
        upscaling = enabled;
        vector = enabled;
      };

      music = enabled;
      office = enabled;
      social = enabled;
      video = enabled;
    };

  };

  home.packages = with pkgs; [
    libation
    # calibre
    uget
  ];

  # daftop's display layout, pinned so it doesn't auto-reset each boot.
  programs.niri.settings.outputs = {
    "eDP-1".enable = false;
    "DP-2".enable = false;

    "HDMI-A-1" = {
      mode = {
        width = 1920;
        height = 1080;
        refresh = 60.0;
      };
      scale = 1.0;
      position = {
        x = 0;
        y = 0;
      };
    };
  };
}
