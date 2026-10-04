# The DMS bar/dock vocabulary every host builds from, published as
# `dafos.desktop.dms.bar.parts`.
#
# Nothing here is a complete setup. A host assembles its own bar list in its
# `homes/daf@<host>/default.nix` by picking the pieces it wants and overriding
# what differs — which is where anything host-shaped (display names, panel
# models) belongs. This file must stay free of host names.
#
# Keep a value here only while every host that uses it agrees on it. When two
# disagree, drop the field from the piece and let each host set it, the way
# `sideBar` already omits `screenPreferences`.
#
# Widget lists accept either a bare id string or an attrset
# ({ id = ...; enabled = ...; <extra opts> }).
#
# `id` fields are DMS's own identifiers. "bar1764155746503" is the opaque id the
# GUI minted when the side bar was first created; `connectedFrameBarStyleBackups`
# in ./settings.json keys off it, so it is kept verbatim rather than renamed to
# something readable.
let
  # The OS logo in the theme's primary colour. DMS moved these two settings off
  # the top level and into the widget (configVersion 37), so every bar that
  # shows a launcher button has to carry them itself.
  launcherButton = {
    id = "launcherButton";
    enabled = true;
    launcherLogoMode = "os";
    launcherLogoColorOverride = "primary";
  };
in
{
  inherit launcherButton;

  # Top bar, every display. Workspaces + focused window on the left, media /
  # clock / weather in the middle, system status on the right.
  mainBar = {
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
    attachToScreenEdge = false;
    hoverPopouts = false;
    followInterfaceStyle = false;

    leftWidgets = [
      launcherButton
      {
        id = "workspaceSwitcher";
        enabled = true;
        # Moved here from the top-level workspaceFollowFocus /
        # workspaceFocusedBorderColor settings, which DMS folded into the
        # widget itself.
        workspaceFollowFocus = true;
        workspaceFocusedBorderColor = "surfaceText";
      }
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
    transparency = 0.75;
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
    widgetTransparency = 0.8;
  };

  # Turns a bar into a DMS "island": the bar collapses to a floating pill that
  # expands on hover/click instead of spanning the panel. Merge it over a bar
  # (`mainBar // islandStyle`) — it is a style, not a bar, so it carries no
  # widgets, geometry or id of its own.
  #
  # The widget lists still apply when the island is expanded; `islandHomeLayout`
  # is what the collapsed pill shows, and its order is the order on screen. A
  # bar that enables the `notifications` group here usually wants
  # `notificationButton` disabled in its rightWidgets, since the pill already
  # carries the badge.
  #
  # Only the values that differ from DMS's island defaults are listed. The rest
  # (satellites, interaction mode, spring physics, `islandPalette`) are left to
  # DMS — check `islandDefaults` in `Common/SettingsData.qml` before adding one.
  islandStyle = {
    island = true;

    # Just the time in the collapsed pill; DMS's "both" adds the date, which
    # the pill has no room for next to media.
    islandHomeClockDisplay = "time";

    islandHomeLayout = [
      {
        id = "media";
        enabled = true;
      }
      {
        id = "clock";
        enabled = true;
      }
      {
        id = "weather";
        enabled = true;
      }
      {
        id = "status";
        enabled = false;
      }
      {
        id = "volume";
        enabled = false;
      }
      {
        id = "brightness";
        enabled = false;
      }
      {
        id = "notifications";
        enabled = true;
      }
    ];
  };

  # Vertical auto-hiding utility bar on the right edge: the things that want a
  # click but not a permanent slot on the main bar.
  #
  # Sparse on purpose — a notepad, a colour picker and a house sensor, with the
  # pomodoro timer parked at the top and the tray at the bottom. A host that
  # wants more hanging off this edge adds to the widget lists; it is easier to
  # hang something on a bar than to get it back off one.
  #
  # Deliberately has NO screenPreferences — a host sets its own, because which
  # panel this bar belongs on is the thing the hosts disagree about.
  sideBar = {
    id = "bar1764155746503";
    name = "Bar 2";
    enabled = true;
    visible = true;
    position = 3; # right
    showOnLastDisplay = false;
    showOnWindowsOpen = false;

    autoHide = true;
    autoHideDelay = 250;
    clickThrough = false;
    maximizeDetection = false;
    openOnOverview = false;
    attachToScreenEdge = false;
    scrollEnabled = false;
    followInterfaceStyle = false;

    # The spacer drops the timer clear of the top corner, where the main bar's
    # right-hand widgets already are.
    leftWidgets = [
      {
        id = "spacer";
        enabled = true;
        size = 25;
      }
      {
        id = "dankPomodoroTimer";
        enabled = true;
      }
    ];
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
        id = "homeAssistantMonitor";
        enabled = true;
      }
    ];
    rightWidgets = [
      {
        id = "systemTray";
        enabled = true;
      }
      {
        id = "cpuTemp";
        enabled = true;
      }
    ];

    # Geometry / spacing
    innerPadding = 20;
    spacing = 4;
    bottomGap = 0;
    fontScale = 1.25;
    popupGapsAuto = true;
    popupGapsManual = 36;

    # Appearance. The outline values are here although the outline is off: a
    # host that turns `widgetOutlineEnabled` on gets the same outline the rest
    # of the fleet draws, rather than DMS's default primary.
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
    widgetOutlineEnabled = false;
    widgetOutlineColor = "secondary";
    widgetOutlineOpacity = 1;
    widgetOutlineThickness = 1;
    widgetTransparency = 0.8;
  };

  # Control-center quick-settings tiles (DMS `controlCenterWidgets`).
  #
  # Each sits on an 8-column grid: `w = 8` is a full row, `w = 4` a half,
  # `w = 2` a quarter. `col`/`row` pin a tile in place (rows step in the tiles'
  # own heights, hence the halves under the 1.5-high user header); a tile
  # without them is packed by DMS. `footer` tiles sit in the bottom strip.
  controlCenterWidgets = [
    {
      actions = [
        "user"
        "settings"
        "power"
        "edit"
        "lock"
      ];
      background = false;
      col = 0;
      compositor = false;
      enabled = true;
      h = 1.5;
      hostname = true;
      id = "user";
      row = 0;
      w = 7;
    }
    {
      col = 0;
      enabled = true;
      h = 1;
      id = "volumeSlider";
      row = 1.5;
      w = 4;
    }
    {
      col = 4;
      enabled = true;
      h = 1;
      id = "brightnessSlider";
      row = 1.5;
      w = 4;
    }
    {
      col = 0;
      enabled = true;
      h = 1;
      id = "audioOutput";
      row = 2.5;
      w = 4;
    }
    {
      col = 4;
      enabled = true;
      h = 1;
      id = "audioInput";
      row = 2.5;
      w = 4;
    }
    {
      col = 0;
      enabled = true;
      h = 1;
      id = "wifi";
      row = 3.5;
      w = 4;
    }
    {
      col = 4;
      enabled = true;
      h = 1;
      id = "builtin_vpn";
      row = 3.5;
      w = 4;
    }
    {
      col = 0;
      enabled = true;
      h = 1;
      id = "bluetooth";
      row = 4.5;
      w = 8;
    }
    {
      col = 0;
      enabled = true;
      h = 1;
      id = "plugin_dankKDEConnect";
      row = 5.5;
      w = 4;
    }
    {
      col = 0;
      enabled = true;
      h = 1;
      id = "nightMode";
      row = 6.5;
      w = 4;
    }
    {
      col = 4;
      enabled = true;
      h = 1;
      id = "darkMode";
      row = 6.5;
      w = 4;
    }
    {
      col = 0;
      enabled = true;
      h = 1;
      id = "idleInhibitor";
      row = 7.5;
      w = 2;
    }
    {
      col = 2;
      enabled = true;
      h = 1;
      id = "colorPicker";
      row = 7.5;
      w = 4;
    }
    {
      col = 6;
      enabled = true;
      h = 1;
      id = "doNotDisturb";
      row = 7.5;
      w = 2;
    }
    {
      col = 0;
      enabled = true;
      h = 1;
      id = "runningApps";
      row = 8.5;
      small = true;
      w = 8;
    }
    {
      col = 7;
      enabled = true;
      h = 1;
      id = "power";
      row = 0;
      small = false;
      w = 1;
    }
    {
      enabled = true;
      footer = true;
      footerEnd = true;
      h = 1;
      id = "edit";
      small = true;
      w = 1;
    }
    {
      col = 4;
      enabled = true;
      h = 1;
      id = "builtin_tailscale";
      row = 5.5;
      w = 4;
    }
  ];

  # The dock (DMS `dockConfigs`). DMS used to spread this over ~13 top-level
  # `dock*` settings; they now live inside one config object per dock, the same
  # shape as a bar.
  #
  # Shared by the whole fleet; only the pinned apps differ per host. Those are
  # NOT here: they are runtime session state, kept declarative through
  # `dafos.desktop.dms.dockApps` (see ../default.nix). `order` leaves them out
  # on purpose — DMS slots pins missing from it in just before the running-apps
  # widget (`unitList` in Common/settings/DockConfig.js), which is where they
  # belong, so the same order works whatever a host pins.
  dockConfigs =
    let
      # Ids are the ones the DMS editor minted; they only have to be unique,
      # but `order` refers to them.
      widget =
        id: widgetId: extra:
        {
          inherit id widgetId;
          enabled = true;
        }
        // extra;
      spacer = id: size: widget id "spacer" { inherit size; };
      separator = id: widget id "separator" { };

      # Left to right: launcher, a pomodoro fenced off by separators, [pins],
      # running apps, trash, weather.
      widgets = [
        (widget "dock_launcher" "dockLauncher" { })
        (spacer "dock_1790156046154" 1)
        (separator "dock_1790156171810")
        (spacer "dock_1790156378298" 1)
        (widget "dock_1790155966987" "dankPomodoroTimer" { })
        (spacer "dock_1790156353557" 1)
        (separator "dock_1790156138183")
        (spacer "dock_1790156038067" 10)
        # Running apps from every workspace, not just the current one.
        (widget "dock_apps" "appsDock" { runningAppsCurrentWorkspace = false; })
        (spacer "dock_1790156008598" 10)
        (separator "dock_1790155984913")
        (widget "dock_trash" "dockTrash" { })
        (separator "dock_1790155931029")
        (spacer "dock_1790156128025" 10)
        (widget "dock_1790155897383" "weather" { })
      ];
    in
    [
      {
        id = "dock";
        name = "Dock";
        enabled = true;
        screenPreferences = [ "all" ];
        showOnLastDisplay = false;
        position = 1; # bottom

        mode = "compact";
        taskbarAlign = "center";
        # Widget popouts (pomodoro, weather) open inside the dock.
        widgetExpansion = "inline";

        # Geometry / spacing
        iconSize = 48;
        spacing = 8;
        itemSpacing = 4;
        margin = 0;
        bottomGap = 0;

        # Behaviour
        autoHide = false;
        smartAutoHide = true;
        useOverlayLayer = true;
        # Right-click opens the in-place editor.
        editOnRightClick = true;
        showOnFullscreen = false;
        openOnOverview = true;
        groupByApp = false;
        separatePinnedAndRunningApps = false;
        restoreSpecialWorkspaceOnClick = false;
        isolateDisplays = false;

        # Appearance
        transparency = 0.85;
        followInterfaceStyle = false;
        indicatorStyle = "line";
        borderEnabled = true;
        borderColor = "primary";
        borderOpacity = 0.55;
        borderThickness = 2;

        launcherEnabled = true;
        launcherLogoMode = "apps";
        launcherLogoCustomPath = "";
        launcherLogoColorOverride = "";
        launcherLogoSizeOffset = 0;
        launcherLogoBrightness = 0.5;
        launcherLogoContrast = 1;

        maxVisibleApps = 0;
        maxVisibleRunningApps = 0;
        showOverflowBadge = true;
        showTrash = true;
        trashFileManager = "default";
        trashCustomCommand = "";

        inherit widgets;
        order = map (w: w.id) widgets;
      }
    ];
}
