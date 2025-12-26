{
  lib,
  config,
  namespace,
  pkgs,
  inputs,
  ...
}:

let
  inherit (lib.${namespace}) enabled;

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
        extraPackages = [ inputs.kwin-effects-forceblur.packages.${pkgs.stdenv.hostPlatform.system}.default ];
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

    programs = {
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

      games = enabled;

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
