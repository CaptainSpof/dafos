{
  lib,
  config,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib.${namespace}) enabled disabled;

  firefox-pkg = config.${namespace}.programs.graphical.browsers.firefox.package;
in
{
  dafos = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    desktop = {
      plasma = {
        themeSwitcher = true;
        config.screenlocker = {
          enable = false;
          lockOnResume = false;
        };
        config.powerdevil.autoSuspend.action = "nothing";
        panels = {
          topPanel = {
            maxLength = 2000;
            minLength = 2000;
          };
          leftPanel.launchers = [
            "applications:org.kde.dolphin.desktop"
            "applications:${toString firefox-pkg.meta.mainProgram}.desktop"
            "applications:org.wezfurlong.wezterm.desktop"
            "applications:emacs.desktop"
            "applications:steam.desktop"
            "applications:vesktop.desktop"
          ];
        };
      };
    };

    services.kanata-notify = enabled;

    services.sops.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/daf@dafbox.pem" ];

    programs = {
      ai = {
        enable = true;
        claude.code = enabled;
        claude.desktop = enabled;
        gemini.cli = enabled;
      };

      graphical = {
        browsers = {
          firefox = {
            enable = true;
            package = pkgs.firefox-beta;
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
      };

      terminal = {
        tools = {
          ssh = enabled;
        };
      };
    };

    suites = {
      common = enabled;
      desktop = enabled;

      development = {
        enable = true;
        aws.enable = true;
      };

      games = {
        enable = true;
        lutris = disabled;
      };

      graphics = {
        enable = true;
        drawing.enable = true;
      };

      music = enabled;
      office = enabled;
      social = enabled;
      video = enabled;
    };
  };

  # dafbox's physical monitors. These outputs are Nix-owned rather than managed
  # by DMS's runtime-generated dms/outputs.kdl. DP-2 runs at 2560x1440@170 (its
  # EDID-preferred mode is only 60Hz) with always-on VRR for adaptive sync.
  programs.niri.settings.outputs = {
    "DP-2" = {
      mode = {
        width = 2560;
        height = 1440;
        refresh = 170.001;
      };
      scale = 1.0;
      position = {
        x = 0;
        y = 0;
      };
      variable-refresh-rate = true;
    };
    "HDMI-A-1" = {
      mode = {
        width = 1920;
        height = 1080;
        refresh = 74.973;
      };
      scale = 1.0;
      position = {
        x = 2560;
        y = 0;
      };
    };
  };

  # Since the outputs above are Nix-owned, drop "outputs" from the DMS include
  # list (upstream default minus "outputs"). Otherwise dms/outputs.kdl would be
  # included after hm.kdl and override them. Other niri hosts keep DMS-managed
  # outputs, so this stays host-specific rather than in the shared dms module.
  programs.dank-material-shell.niri.includes.filesToInclude = [
    "alttab"
    "binds"
    "colors"
    "cursor"
    "layout"
    "windowrules"
    "wpblur"
  ];
}
