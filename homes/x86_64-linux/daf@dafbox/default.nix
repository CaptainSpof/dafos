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
}
