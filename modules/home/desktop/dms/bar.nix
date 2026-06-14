# DMS "bar setup" expressed in Nix: the bar layout (barConfigs) and the
# control-center quick-settings tiles (controlCenterWidgets). These are the
# defaults for the dafos.desktop.dms.bar.{configs,controlCenterWidgets} options;
# override either per host in homes/<user>@<host> to give a machine a different
# bar / control center (e.g. dafbox has no eDP-1, so it doesn't need "Bar 2").
#
# Widget lists accept either a bare id string or an attrset
# ({ id = ...; enabled = ...; <extra opts> }). Applied via the DMS settings
# seed, so edits take effect on re-baseline (see the seedDmsSettings note in
# default.nix).
{
  # Bars (DMS `barConfigs`). Each entry is one bar.
  configs = [
    {
      id = "default";
      name = "Main Bar";
      enabled = true;
      visible = true;
      position = 0; # top
      screenPreferences = [ "all" ];
      showOnLastDisplay = true;

      autoHide = false;
      autoHideDelay = 250;
      clickThrough = false;
      maximizeDetection = true;
      openOnOverview = false;

      leftWidgets = [
        "launcherButton"
        "workspaceSwitcher"
        {
          id = "focusedWindow";
          enabled = true;
          focusedWindowCompactMode = true;
        }
      ];
      centerWidgets = [
        {
          id = "music";
          enabled = true;
        }
        {
          id = "spacer";
          enabled = true;
          size = 20;
        }
        {
          id = "clock";
          enabled = true;
        }
        {
          id = "spacer";
          enabled = true;
          size = 5;
        }
        {
          id = "weather";
          enabled = true;
        }
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
        }
        {
          id = "memUsage";
          enabled = true;
        }
        {
          id = "notificationButton";
          enabled = true;
        }
        {
          id = "battery";
          enabled = true;
        }
        {
          id = "controlCenterButton";
          enabled = true;
        }
      ];

      # Geometry / spacing
      innerPadding = 5;
      spacing = 6;
      bottomGap = 0;
      fontScale = 1.05;
      popupGapsAuto = true;
      popupGapsManual = 4;

      # Appearance
      noBackground = true;
      transparency = 0.8;
      squareCorners = false;
      borderEnabled = false;
      borderColor = "surfaceText";
      borderOpacity = 1;
      borderThickness = 1;
      gothCornersEnabled = false;
      gothCornerRadiusOverride = false;
      gothCornerRadiusValue = 12;
      shadowColorMode = "surface";
      shadowIntensity = 0;
      shadowOpacity = 40;
      widgetOutlineEnabled = false;
      widgetPadding = 5;
      widgetTransparency = 0.75;
    }

    {
      id = "bar1764155746503";
      name = "Bar 2";
      enabled = true;
      visible = true;
      position = 3; # right
      # Pinned to the laptop's internal panel; only present on daftop.
      screenPreferences = [
        {
          name = "eDP-1";
          model = "0x8A98";
        }
      ];
      showOnLastDisplay = false;
      showOnWindowsOpen = false;

      autoHide = true;
      autoHideDelay = 250;
      maximizeDetection = false;
      openOnOverview = true;
      scrollEnabled = false;

      leftWidgets = [ ];
      centerWidgets = [
        {
          id = "notepadButton";
          enabled = true;
        }
        {
          id = "colorPicker";
          enabled = true;
        }
        {
          id = "wallpaperDiscovery";
          enabled = true;
        }
        {
          id = "dankKDEConnect";
          enabled = true;
        }
        {
          id = "dankPomodoroTimer";
          enabled = true;
        }
        {
          id = "dankClight";
          enabled = true;
        }
        {
          id = "tailscale";
          enabled = true;
        }
        {
          id = "homeAssistantMonitor";
          enabled = true;
        }
      ];
      rightWidgets = [
        {
          id = "idleInhibitor";
          enabled = true;
        }
        {
          id = "systemTray";
          enabled = true;
        }
        {
          id = "keyboard_layout_name";
          enabled = true;
          keyboardLayoutNameCompactMode = true;
        }
        {
          id = "clipboard";
          enabled = true;
        }
        {
          id = "vpn";
          enabled = true;
        }
      ];

      # Geometry / spacing
      innerPadding = 6;
      spacing = 10;
      bottomGap = 0;
      fontScale = 1.25;
      popupGapsAuto = true;
      popupGapsManual = 36;

      # Appearance
      noBackground = false;
      transparency = 0;
      squareCorners = false;
      borderEnabled = false;
      borderColor = "surfaceText";
      borderOpacity = 1;
      borderThickness = 1;
      gothCornersEnabled = false;
      gothCornerRadiusOverride = false;
      gothCornerRadiusValue = 28;
      shadowIntensity = 0;
      widgetOutlineEnabled = true;
      widgetOutlineColor = "secondary";
      widgetOutlineOpacity = 1;
      widgetOutlineThickness = 1;
      widgetTransparency = 0.8;
    }
  ];

  # Control-center quick-settings tiles (DMS `controlCenterWidgets`).
  # Each is { id; enabled; width } where width is a percentage (50 = half row).
  controlCenterWidgets = [
    {
      id = "volumeSlider";
      enabled = true;
      width = 50;
    }
    {
      id = "brightnessSlider";
      enabled = true;
      width = 50;
    }
    {
      id = "audioOutput";
      enabled = true;
      width = 50;
    }
    {
      id = "audioInput";
      enabled = true;
      width = 50;
    }
    {
      id = "wifi";
      enabled = true;
      width = 50;
    }
    {
      id = "builtin_vpn";
      enabled = true;
      width = 50;
    }
    {
      id = "bluetooth";
      enabled = true;
      width = 100;
    }
    {
      id = "nightMode";
      enabled = true;
      width = 50;
    }
    {
      id = "darkMode";
      enabled = true;
      width = 50;
    }
    {
      id = "idleInhibitor";
      enabled = true;
      width = 50;
    }
    {
      id = "doNotDisturb";
      enabled = true;
      width = 50;
    }
    {
      id = "colorPicker";
      enabled = true;
      width = 100;
    }
    {
      id = "battery";
      enabled = true;
      width = 100;
    }
    {
      id = "plugin_dankKDEConnect";
      enabled = true;
      width = 100;
    }
  ];
}
