{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.desktop.plasma.config;
in
{
  options.${namespace}.desktop.plasma.config = with types; {
    enable = mkBoolOpt false "Whether or not to configure plasma config.";
    screenlocker.enable = mkBoolOpt true "Whether or not to enable the screen locker.";
    screenlocker.lockOnResume = mkBoolOpt true "Whether or not to lock the screen on resume.";
    powerdevil.autoSuspend.action = mkOpt (enum [
      "nothing"
      "sleep"
    ]) "sleep" "The action to execute when the system is inactive.";
    powerdevil.turnOffDisplay.idleTimeout =
      mkOpt (nullOr (either (enum [ "never" ]) (ints.between 30 600000))) null
        "The duration (in seconds), the computer must be idle
          (when unlocked) until the display turns off.";
  };

  config = mkIf cfg.enable {
    programs.plasma = {
      input = {
        keyboard = {
          layouts = [
            {
              layout = "fr";
              variant = "ergol";
              displayName = "er";
            }
            {
              layout = "fr";
              variant = "bepo";
              displayName = "bé";
            }
            {
              layout = "fr";
              variant = "us";
              displayName = "fr";
            }
          ];
          numlockOnStartup = "on";
        };
        touchpads = [
          {
            name = "MSFT0001:00 06CB:CE44 Touchpad";
            enable = true;
            vendorId = "06cb";
            productId = "ce44";
            disableWhileTyping = true;
            leftHanded = false;
            pointerSpeed = 0;
            naturalScroll = true;
            tapToClick = true;
          }
        ];
        # mice = [
        #   {
        #     name = "Logitech G502";
        #    TODO: add vendorId
        #     naturalScroll = true;
        #   }
        # ];
      };

      powerdevil.AC = {
        inherit (cfg.powerdevil) autoSuspend turnOffDisplay;
      };

      kscreenlocker = {
        appearance = {
          alwaysShowClock = true;
          showMediaControls = true;
          wallpaperPictureOfTheDay.provider = "bing";
        };
        autoLock = cfg.screenlocker.enable;
        inherit (cfg.screenlocker) lockOnResume;
        lockOnStartup = false;
        passwordRequired = true;
        passwordRequiredDelay = 10;
        timeout = 10;
      };

      krunner = {
        activateWhenTypingOnDesktop = true;
        position = "center";
        historyBehavior = "enableAutoComplete";
      };

      configFile = {
        baloofilerc."Basic Settings".Indexing-Enabled = false;

        dolphinrc.VersionControl.enabledPlugins = "Git";

        ksmserverrc = {
          General.loginMode = "emptySession";
        };

        ## Peripherals
        # Tablet settings
        kcminputrc = {
          "ButtonRebinds.Tablet.Wacom Intuos BT S Pad"."0" = "Key,Ctrl+Z";
          "ButtonRebinds.Tablet.Wacom Intuos Pro S Pad"."0" = "Key,Ctrl+Z";
          "ButtonRebinds.Tablet.Wacom Intuos Pro S Pad"."6" = "Key,Ctrl+Z";
          "Libinput.1386.914.Wacom Intuos Pro S Finger"."NaturalScroll" = true;
          "Libinput.1386.914.Wacom Intuos Pro S Finger"."PointerAccelerationProfile" = 1;
          # Mouse settings
          "Libinput.1133.16511.Logitech G502"."PointerAccelerationProfile" = 1;
        };
      };
    };
  };
}
