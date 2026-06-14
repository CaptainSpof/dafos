{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.graphical.instant-messengers.discord;
in
{
  options.${namespace}.programs.graphical.instant-messengers.discord = {
    enable = mkBoolOpt false "Whether or not to enable Discord.";
    canary.enable = mkBoolOpt false "Whether or not to enable Discord Canary.";
    vesktop.enable = mkBoolOpt true "Whether or not to enable Discord Vesktop.";
    firefox.enable = mkBoolOpt false "Whether or not to enable the Firefox version of Discord.";
  };

  config = mkIf cfg.enable {

    # FIXME
    # lib.optional cfg.enable pkgs.discord
    home.packages =
      lib.optional cfg.canary.enable pkgs.dafos.discord
      ++ lib.optional cfg.vesktop.enable pkgs.vesktop
      ++ lib.optional cfg.firefox.enable pkgs.dafos.discord-firefox;

    programs.vesktop = {
      # Vesktop/Vencord documentation
      # See: https://vencord.dev/
      enable = true;

      settings = {
        discordBranch = "stable";
        # Easier to close and be done with it
        minimizeToTray = false;
        arRPC = true;
        customTitleBar = false;
      };

      vencord = {
        settings = {
          # Can't auto update on nix
          autoUpdate = false;
          autoUpdateNotification = false;

          useQuickCss = true;
          themeLinks = [ ];
          # dank-discord.css is generated at runtime by DMS's matugen
          # integration (enableDynamicTheming) and kept in sync with the
          # active color scheme.
          enabledThemes = [ "dank-discord.css" ];
          eagerPatches = false;
          enableReactDevtools = true;
          frameless = false;
          transparent = true;
          winCtrlQ = false;
          disableMinSize = true;
          winNativeTitleBar = false;
          plugins = {
            CommandsAPI = {
              enabled = true;
            };
            MessageAccessoriesAPI = {
              enabled = true;
            };
            UserSettingsAPI = {
              enabled = true;
            };
            AlwaysAnimate = {
              enabled = true;
            };
            AlwaysExpandRoles = {
              enabled = true;
            };
            AlwaysTrust = {
              enabled = true;
            };
            BetterSessions = {
              enabled = true;
            };
            CrashHandler = {
              enabled = true;
            };
            FixImagesQuality = {
              enabled = true;
            };
            PlatformIndicators = {
              enabled = true;
            };
            ReplyTimestamp = {
              enabled = true;
            };
            ShowHiddenChannels = {
              enabled = true;
            };
            ShowHiddenThings = {
              enabled = true;
            };
            VencordToolbox = {
              enabled = true;
            };
            WebKeybinds = {
              enabled = true;
            };
            WebScreenShareFixes = {
              enabled = true;
            };
            # Lag inducing on large servers
            # WhoReacted= {
            #     enabled= false
            # };
            YoutubeAdblock = {
              enabled = true;
            };
            BadgeAPI = {
              enabled = true;
            };
            NoTrack = {
              enabled = true;
              disableAnalytics = true;
            };
            Settings = {
              enabled = true;
              settingsLocation = "aboveNitro";
            };
          };
          notifications = {
            timeout = 5000;
            position = "bottom-right";
            useNative = "not-focused";
            logLimit = 50;
          };
        };
      };
    };

  };
}
