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

  # flake-firefox-nightly still advertises the pre-rename `ffmpegSupport`
  # passthru, but nixpkgs' firefox wrapper now reads `withFFmpeg` — so ffmpeg
  # gets dropped from the wrapper's LD_LIBRARY_PATH and Firefox loses H.264/AAC
  # ("your browser may not support the required H.264 or AAC codecs" on every
  # Twitch stream). The bundled ffvpx is built with
  # `--enable-decoder='vp8,vp9,mp3,flac,av1'`, so there is no fallback decoder.
  # Re-wrap exactly the way the flake does, with the flag under its new name.
  # Drop this once flake-firefox-nightly's package.nix renames the passthru.
  firefox-nightly-bin =
    let
      unwrapped =
        inputs.firefox.packages.${pkgs.stdenv.hostPlatform.system}.firefox-nightly-bin.unwrapped.overrideAttrs
          (old: {
            passthru = old.passthru // {
              withFFmpeg = old.passthru.ffmpegSupport;
            };
          });
    in
    pkgs.wrapFirefox unwrapped { pname = "${unwrapped.binaryName}-bin"; };
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
            package = firefox-nightly-bin;
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
