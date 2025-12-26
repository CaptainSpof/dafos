{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;
  inherit (config.${namespace}.user) home;

  cfg = config.${namespace}.desktop.noctalia-shell;
in
{
  options.${namespace}.desktop.noctalia-shell = {
    enable = mkBoolOpt true "Whether or not to use noctalia-shell";
  };

  config = mkIf cfg.enable {
    programs = {
      noctalia-shell = {
        enable = true;
        systemd.enable = true;
        settings = {
          bar = {
            position = "top";
            backgroundOpacity = 0;
            monitors = [ ];
            density = "comfortable";
            showCapsule = true;
            floating = false;
            marginVertical = 0.4;
            marginHorizontal = 0.4;
            outerCorners = true;
            exclusive = true;
            widgets = {
              left = [
                {
                  id = "ControlCenter";
                }
                {
                  id = "SystemMonitor";
                  showMemoryAsPercent = true;
                  showNetworkStats = true;
                }
                {
                  id = "ActiveWindow";
                }
                {
                  id = "MediaMini";
                }
              ];
              center = [
                {
                  id = "Clock";
                  usePrimaryColor = false;
                  formatHorizontal = "dddd dd MMMM · HH:mm";
                }
              ];
              right = [
                {
                  id = "Workspace";
                  labelMode = "none";
                }
                {
                  id = "WiFi";
                }
                {
                  id = "KeepAwake";
                }
                {
                  id = "Tray";
                }
                {
                  id = "NotificationHistory";
                }
                {
                  id = "Battery";
                  displayMode = "alwaysShow";
                  warningThreshold = 30;
                }
                {
                  id = "Volume";
                }
                {
                  id = "Brightness";
                }
                {
                  id = "SessionMenu";
                }
              ];
            };
          };

          colorSchemes = {
            predefinedScheme = "Kanagawa";
            # useWallpaperColors = true;
          };
          general = {
            avatarImage = "/home/drfoobar/.face";
            radiusRatio = 0.6;
          };
          dock = {
            displayMode = "auto_hide";
            floatingRatio = 0.5;
            size = 1.5;
          };
          location = {
            monthBeforeDay = false;
            name = "Paris, France";
            firstDayOfWeek = 1;
          };
          wallpaper = {
            directory = "${home}/Pictures/wallpapers/";
            overviewEnabled = true;
            recursiveSearch = true;
            randomEnabled = true;
            randomIntervalSec = 180;
            defaultWallpaper = "${home}/Pictures/wallpapers/annapurna.png";
          };
          templates = {
            qt = false;
            vicinae = false;
            wezterm = false;
          };
        };
        # this may also be a string or a path to a JSON file,
        # but in this case must include *all* settings.
      };
    };
  };
}
