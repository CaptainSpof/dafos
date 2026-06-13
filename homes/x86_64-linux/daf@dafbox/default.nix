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
        themeSwitcher = false;
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

    system.xdg = enabled;

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

  # dafbox's physical monitors. Nix owns these (the shared dms module pins
  # monitors.json empty and drops "outputs" from DMS's includes, so DMS can't
  # override them). DP-2 runs at 2560x1440@170 (its EDID-preferred mode is only
  # 60Hz) with always-on VRR for adaptive sync.
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
}
