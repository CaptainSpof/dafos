{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.desktop.plasma.panels;
  firefox-pkg = config.${namespace}.programs.graphical.browsers.firefox.package;

  toggle-panel = pkgs.writeShellScriptBin "toggle-panel" ''
    qdbus org.kde.plasmashell /PlasmaShell evaluateScript "p = panelById(panelIds[1]); p.hiding = (p.hiding == 'autohide') ? 'windowsgobelow' : 'autohide';"
  '';

  sharedPanelConfig = {
    alignment = "center";
    floating = true;
    lengthMode = "custom";
  };

  widgets = {
    netSpeed = {
      name = "org.kde.netspeedWidget";
      config = {
        general = {
          shortUnits = true;
        };
      };
    };
    cpuUsage = {
      systemMonitor = {
        title = "CPU Usage";
        displayStyle = "org.kde.ksysguard.linechart";
        sensors = [
          {
            name = "cpu/all/usage";
            color = "250,179,135"; # Peach
            label = "CPU Usage";
          }
        ];
        totalSensors = [ "cpu/all/usage" ];
        textOnlySensors = [
          "cpu/all/averageTemperature"
          "cpu/all/averageFrequency"
        ];
      };
    };
    memUsage = {
      systemMonitor = {
        title = "Memory Usage";
        displayStyle = "org.kde.ksysguard.linechart";
        sensors = [
          {
            name = "memory/physical/usedPercent";
            color = "166,227,161"; # Green
            label = "Memory Usage";
          }
        ];
        totalSensors = [ "memory/physical/usedPercent" ];
        textOnlySensors = [
          "memory/physical/used"
          "memory/physical/total"
        ];
      };
    };
    plasmusic = {
      plasmusicToolbar = {
        musicControls = {
          showPlaybackControls = false;
          volumeStep = 1;
        };
        panelIcon = {
          albumCover = {
            useAsIcon = true;
            fallbackToIcon = true;
            radius = 8;
          };
          icon = "view-media-track";
        };
        songText = {
          displayInSeparateLines = true;
          maximumWidth = 0;
        };
      };
    };
    systray = {
      systemTray = {
        icons = {
          scaleToFit = false;
          spacing = "small";
        };

        items = {
          shown = [
            "org.kde.plasma.battery"
            "org.kde.plasma.bluetooth"
            "org.kde.plasma.networkmanagement"
            "org.kde.plasma.volume"
          ];
          hidden = [
            "org.kde.kdeconnect"
            "org.kde.merkuro.contact.applet"
            "org.kde.plasma.keyboardlayout"
            "org.kde.plasma.kweather_1x4"
          ];
          configs = {
            battery.showPercentage = true;
          };
        };
      };
    };
    digitalclock = {
      digitalClock = {
        date = {
          enable = true;
          format.custom = "ddd dd";
          position = "belowTime";
        };
      };
    };
  };

  leftPanelConfig = sharedPanelConfig // {
    location = "left";
    screen = 0;
    height = 60;
    widgets = [
      widgets.netSpeed
      widgets.cpuUsage
      widgets.memUsage
      "org.kde.plasma.panelspacer"
      "org.kde.plasma.marginsseparator"
      {
        iconTasks = {
          appearance = {
            fill = false;
            highlightWindows = true;
            iconSpacing = "medium";
            indicateAudioStreams = true;
            rows = {
              multirowView = "never";
              maximum = null;
            };
            showTooltips = true;
          };
          behavior = {
            grouping = {
              clickAction = "showPresentWindowsEffect";
              method = "byProgramName";
            };
            middleClickAction = "newInstance";
            minimizeActiveTaskOnClick = true;
            newTasksAppearOn = "right";
            showTasks = {
              onlyInCurrentActivity = true;
              onlyInCurrentDesktop = true;
              onlyMinimized = false;
              onlyInCurrentScreen = false;
            };
            sortingMethod = "manually";
            unhideOnAttentionNeeded = true;
            wheel = {
              ignoreMinimizedTasks = true;
              switchBetweenTasks = true;
            };
          };
          inherit (cfg.leftPanel) launchers;
        };
      }
      "org.kde.plasma.marginsseparator"
      "org.kde.plasma.panelspacer"
      widgets.plasmusic
      widgets.systray
      widgets.digitalclock
      {
        name = "org.dhruv8sh.kara";
        config = {
          general = {
            animationDuration = 200;
            spacing = 3;
            type = 0;
          };
          type1 = {
            t1activeWidth = 15;
          };
        };
      }
      {
        kickoff = {
          applicationsDisplayMode = "list";
          compactDisplayStyle = false;
          favoritesDisplayMode = "grid";
          icon = "choice-round";
          label = null;
          pin = false;
          showActionButtonCaptions = true;
          showButtonsFor = "power";
          sidebarPosition = "right";
          sortAlphabetically = true;
        };
      }
    ];
  };

  leftPanelSecondScreenConfig = sharedPanelConfig // {
    location = "left";
    hiding = "autohide";
    screen = 1;
    height = 100;
    widgets = [
      widgets.netSpeed
      widgets.cpuUsage
      widgets.memUsage
      "org.kde.plasma.panelspacer"
      widgets.plasmusic
      widgets.systray
      widgets.digitalclock
    ];
  };

  topPanelConfig = sharedPanelConfig // {
    height = 32;
    hiding = "autohide";
    location = "top";
    widgets = [
      {
        applicationTitleBar = {
          behavior = {
            activeTaskSource = "activeTask";
            disableButtonsForNotHovered = false;
            disableForNotMaximized = false;
            filterByActivity = true;
            filterByScreen = true;
            filterByVirtualDesktop = true;
          };

          layout = {
            elements = [ "windowTitle" ];
            fillFreeSpace = false;
            horizontalAlignment = "left";
            showDisabledElements = "deactivated";
            spacingBetweenElements = 0;
            verticalAlignment = "center";
            widgetMargins = 1;
          };

          overrideForMaximized = {
            enable = true;
            elements = [
              "windowCloseButton"
              "windowMinimizeButton"
              "windowMaximizeButton"
              "windowTitle"
              "spacer"
            ];
          };

          windowControlButtons = {
            auroraeTheme = null;
            buttonsAnimationSpeed = 100;
            buttonsAspectRatio = 100;
            buttonsMargin = 0;
            iconSource = "plasma";
          };

          windowTitle = {
            font.bold = false;
            hideEmptyTitle = true;

            margins = {
              bottom = 0;
              left = 15;
              right = 5;
              top = 0;
            };

            source = "appName";
            undefinedWindowTitle = "";
          };
        };
      }
      "org.kde.plasma.panelspacer"
      "org.kde.plasma.marginsseparator"
      (
        widgets.digitalclock
        // {
          digitalClock.date = {
            format.custom = "dddd d MMMM ·";
            position = "besideTime";
          };
        }
      )
      "org.kde.plasma.marginsseparator"
      "org.kde.plasma.panelspacer"
    ];
  };

  topPanelPrimaryScreen = topPanelConfig // {
    screen = 0;
    inherit (cfg.topPanel) maxLength minLength;
  };

  topPanelSecondaryScreen = topPanelConfig // {
    screen = 1;
  };
in
{
  options.${namespace}.desktop.plasma.panels = with types; {
    enable = mkBoolOpt false "Whether or not to configure plasma panels.";

    topPanel = {
      maxLength = mkOpt number 1600 "The maximum length of the top panel.";
      minLength = mkOpt number 1600 "The minimum length of the top panel.";
    };

    leftPanel = {
      launchers = mkOpt (listOf str) [
        "applications:org.kde.dolphin.desktop"
        "applications:${toString firefox-pkg.meta.mainProgram}.desktop"
        "applications:org.wezfurlong.wezterm.desktop"
        "applications:emacs.desktop"
      ] "The launchers to display in the panel.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ toggle-panel ];

    programs.plasma.panels = [
      leftPanelConfig
      leftPanelSecondScreenConfig
      # Global menu at the top
      topPanelPrimaryScreen
      topPanelSecondaryScreen
    ];
  };
}
