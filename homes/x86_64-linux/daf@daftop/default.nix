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
in
{
  dafos = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    desktop = {
      plasma = {
        touchScreen = false;
        themeSwitcher = false;
        desktop.digitalClock.position.horizontal = 1200;
      };
    };

    programs = {
      rustdesk = enabled;

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
        instant-messengers.teamspeak = enabled;
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
