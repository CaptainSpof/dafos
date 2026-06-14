{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  matugenConfigDir = "${config.xdg.configHome}/matugen";
  templatePath = "${matugenConfigDir}/templates/qtct-colors.conf";

  targetOutputPath = "${config.xdg.configHome}/qt6ct/colors/matugen.conf";

  qt6ctConfPath = "${config.xdg.configHome}/qt6ct/qt6ct.conf";
  qt6ctConf = pkgs.writeText "qt6ct.conf" ''
    [Appearance]
    style=Darkly
    custom_palette=true
    color_scheme_path=${targetOutputPath}
    icon_theme=Papirus-Dark
  '';

  cfg = config.${namespace}.desktop.dms;

  # Bar setup (bar layout + control-center tiles) extracted to Nix; see bar.nix.
  barSetup = import ./bar.nix;

  # User location (lat/long/name), reused to fix the DMS weather widget's
  # location instead of DMS's IP-based auto location.
  userLocation = config.${namespace}.user.location;

  # DMS settings baseline. The bulky structural config (widgets, desktop widget
  # instances) lives in the ./settings.json snapshot;
  dmsSettings = lib.recursiveUpdate (lib.importJSON ./settings.json) {
    barConfigs = cfg.bar.configs;
    controlCenterWidgets = cfg.bar.controlCenterWidgets;

    # Fonts
    fontFamily = "Inter Variable";
    monoFontFamily = "Fira Code";
    fontWeight = 400;
    fontScale = 1;

    # Clock & locale
    use24HourClock = true;
    showSeconds = false;
    padHours12Hour = false;
    firstDayOfWeek = -1; # locale default
    showWeekNumber = false;
    clockDateFormat = "dddd d MMMM";
    useFahrenheit = false;
    windSpeedUnit = "kmh";

    # Theming
    currentThemeName = "dynamic";
    currentThemeCategory = "dynamic";
    matugenScheme = "scheme-fidelity";
    matugenContrast = 0;
    runUserMatugenTemplates = true;
    gtkThemingEnabled = false;
    qtThemingEnabled = false;
    syncModeWithPortal = true;
    terminalsAlwaysDark = true;
    iconTheme = "System Default";
    nightModeEnabled = false;

    # Behaviour
    weatherEnabled = true;
    useAutoLocation = false;
    audioVisualizerEnabled = true;
    soundsEnabled = true;
    networkPreference = "ethernet";

    # Launcher logo (path derived from the home directory)
    launcherLogoMode = "os";
    launcherStyle = "full";
  };

  dmsSettingsSeed = (pkgs.formats.json { }).generate "dms-settings-seed.json" dmsSettings;
  dmsSettingsPath = "${config.xdg.configHome}/DankMaterialShell/settings.json";

  # DMS session state (dock pinned apps, wallpaper, night mode, …) lives here.
  dmsSessionPath = "${config.xdg.stateHome}/DankMaterialShell/session.json";
in
{
  options.${namespace}.desktop.dms = {
    enable = mkBoolOpt true "Whether or not to use dms";

    dockApps = mkOpt (with lib.types; listOf str) [
      "firefox-nightly"
      "emacs"
      "steam"
      "org.wezfurlong.wezterm"
      "org.kde.dolphin"
    ] "App IDs (desktop-entry basenames) pinned to the DMS dock, in order. Override per host.";

    bar = {
      configs =
        mkOpt (with lib.types; listOf attrs) barSetup.configs
          "DMS bar layout (barConfigs), in Nix. Defaults to ./bar.nix; override per host for a different set of bars.";
      controlCenterWidgets =
        mkOpt (with lib.types; listOf attrs) barSetup.controlCenterWidgets
          "DMS control-center quick-settings tiles. Defaults to ./bar.nix; override per host.";
    };
  };

  config = mkIf cfg.enable {

    xdg.configFile."matugen/templates/qtct-colors.conf".text = ''
      [ColorScheme]
      active_colors={{colors.on_surface.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface_container.default.hex}}, {{colors.outline.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.outline_variant.default.hex}}, {{colors.on_surface.default.hex}}, {{colors.on_primary.default.hex}}, {{colors.on_surface.default.hex}}, {{colors.surface_container.default.hex}}, {{colors.background.default.hex}}, {{colors.shadow.default.hex}}, {{colors.primary.default.hex}}, {{colors.on_primary.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface_container_low.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}
      disabled_colors={{colors.on_surface_variant.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.surface_container.default.hex}}, {{colors.outline.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.outline_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.shadow.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}
      inactive_colors={{colors.on_surface_variant.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface_container.default.hex}}, {{colors.outline.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.outline_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.surface_container.default.hex}}, {{colors.surface.default.hex}}, {{colors.shadow.default.hex}}, {{colors.outline.default.hex}}, {{colors.on_secondary.default.hex}}, {{colors.secondary.default.hex}}, {{colors.secondary.default.hex}}, {{colors.surface_container_low.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}

      [ColorEffects:Disabled]
      Color={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
      ColorAmount=0
      ColorEffect=0
      ContrastAmount=0.65
      ContrastEffect=1
      IntensityAmount=0.1
      IntensityEffect=2

      [ColorEffects:Inactive]
      ChangeSelectionColor=true
      Color={{colors.outline.default.red}},{{colors.outline.default.green}},{{colors.outline.default.blue}}
      ColorAmount=0.025
      ColorEffect=2
      ContrastAmount=0.1
      ContrastEffect=2
      Enable=false
      IntensityAmount=0
      IntensityEffect=0

      [Colors:Button]
      BackgroundAlternate={{colors.surface_container.default.red}},{{colors.surface_container.default.green}},{{colors.surface_container.default.blue}}
      BackgroundNormal={{colors.surface.default.red}},{{colors.surface.default.green}},{{colors.surface.default.blue}}
      DecorationFocus={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      DecorationHover={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundActive={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundInactive={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
      ForegroundLink={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundNegative={{colors.error.default.red}},{{colors.error.default.green}},{{colors.error.default.blue}}
      ForegroundNeutral={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}
      ForegroundNormal={{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}}
      ForegroundPositive={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundVisited={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}

      [Colors:Complementary]
      BackgroundAlternate={{colors.surface_container.default.red}},{{colors.surface_container.default.green}},{{colors.surface_container.default.blue}}
      BackgroundNormal={{colors.background.default.red}},{{colors.background.default.green}},{{colors.background.default.blue}}
      DecorationFocus={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      DecorationHover={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundActive={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundInactive={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
      ForegroundLink={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundNegative={{colors.error.default.red}},{{colors.error.default.green}},{{colors.error.default.blue}}
      ForegroundNeutral={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}
      ForegroundNormal={{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}}
      ForegroundPositive={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundVisited={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}

      [Colors:Header]
      BackgroundAlternate={{colors.background.default.red}},{{colors.background.default.green}},{{colors.background.default.blue}}
      BackgroundNormal={{colors.surface.default.red}},{{colors.surface.default.green}},{{colors.surface.default.blue}}
      DecorationFocus={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      DecorationHover={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundActive={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundInactive={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
      ForegroundLink={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundNegative={{colors.error.default.red}},{{colors.error.default.green}},{{colors.error.default.blue}}
      ForegroundNeutral={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}
      ForegroundNormal={{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}}
      ForegroundPositive={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundVisited={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}

      [Colors:Header][Inactive]
      BackgroundAlternate={{colors.surface.default.red}},{{colors.surface.default.green}},{{colors.surface.default.blue}}
      BackgroundNormal={{colors.background.default.red}},{{colors.background.default.green}},{{colors.background.default.blue}}
      DecorationFocus={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      DecorationHover={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundActive={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundInactive={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
      ForegroundLink={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundNegative={{colors.error.default.red}},{{colors.error.default.green}},{{colors.error.default.blue}}
      ForegroundNeutral={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}
      ForegroundNormal={{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}}
      ForegroundPositive={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundVisited={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}

      [Colors:Selection]
      BackgroundAlternate={{colors.primary_container.default.red}},{{colors.primary_container.default.green}},{{colors.primary_container.default.blue}}
      BackgroundNormal={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      DecorationFocus={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      DecorationHover={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundActive={{colors.on_primary.default.red}},{{colors.on_primary.default.green}},{{colors.on_primary.default.blue}}
      ForegroundInactive={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
      ForegroundLink={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundNegative={{colors.error.default.red}},{{colors.error.default.green}},{{colors.error.default.blue}}
      ForegroundNeutral={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}
      ForegroundNormal={{colors.on_primary.default.red}},{{colors.on_primary.default.green}},{{colors.on_primary.default.blue}}
      ForegroundPositive={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundVisited={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}

      [Colors:Tooltip]
      BackgroundAlternate={{colors.background.default.red}},{{colors.background.default.green}},{{colors.background.default.blue}}
      BackgroundNormal={{colors.surface.default.red}},{{colors.surface.default.green}},{{colors.surface.default.blue}}
      DecorationFocus={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      DecorationHover={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundActive={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundInactive={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
      ForegroundLink={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundNegative={{colors.error.default.red}},{{colors.error.default.green}},{{colors.error.default.blue}}
      ForegroundNeutral={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}
      ForegroundNormal={{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}}
      ForegroundPositive={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundVisited={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}

      [Colors:View]
      BackgroundAlternate={{colors.surface_container_low.default.red}},{{colors.surface_container_low.default.green}},{{colors.surface_container_low.default.blue}}
      BackgroundNormal={{colors.background.default.red}},{{colors.background.default.green}},{{colors.background.default.blue}}
      DecorationFocus={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      DecorationHover={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundActive={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundInactive={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
      ForegroundLink={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundNegative={{colors.error.default.red}},{{colors.error.default.green}},{{colors.error.default.blue}}
      ForegroundNeutral={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}
      ForegroundNormal={{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}}
      ForegroundPositive={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundVisited={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}

      [Colors:Window]
      BackgroundAlternate={{colors.surface.default.red}},{{colors.surface.default.green}},{{colors.surface.default.blue}}
      BackgroundNormal={{colors.background.default.red}},{{colors.background.default.green}},{{colors.background.default.blue}}
      DecorationFocus={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      DecorationHover={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundActive={{colors.primary.default.red}},{{colors.primary.default.green}},{{colors.primary.default.blue}}
      ForegroundInactive={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
      ForegroundLink={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundNegative={{colors.error.default.red}},{{colors.error.default.green}},{{colors.error.default.blue}}
      ForegroundNeutral={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}
      ForegroundNormal={{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}}
      ForegroundPositive={{colors.tertiary.default.red}},{{colors.tertiary.default.green}},{{colors.tertiary.default.blue}}
      ForegroundVisited={{colors.secondary.default.red}},{{colors.secondary.default.green}},{{colors.secondary.default.blue}}

      [WM]
      activeBackground={{colors.surface.default.red}},{{colors.surface.default.green}},{{colors.surface.default.blue}}
      activeBlend={{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}}
      activeForeground={{colors.on_surface.default.red}},{{colors.on_surface.default.green}},{{colors.on_surface.default.blue}}
      inactiveBackground={{colors.background.default.red}},{{colors.background.default.green}},{{colors.background.default.blue}}
      inactiveBlend={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
      inactiveForeground={{colors.on_surface_variant.default.red}},{{colors.on_surface_variant.default.green}},{{colors.on_surface_variant.default.blue}}
    '';

    xdg.configFile."matugen/config.toml".text = lib.mkForce ''
      [config]
      # General Matugen settings can go here

      [templates.custom_qt6ct]
      input_path = "${templatePath}"
      output_path = "${targetOutputPath}"
    '';

    systemd.user.services.qt6ct-reload = {
      Unit = {
        Description = "Reload qt6ct when matugen colors change";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/touch %h/.config/qt6ct/qt6ct.conf";
      };
    };

    systemd.user.paths.qt6ct-reload = {
      Unit = {
        Description = "Watch matugen color file for changes";
      };
      Path = {
        PathModified = "%h/.config/qt6ct/colors/matugen.conf";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    systemd.user.services.dms.Service.ExecCondition = ''
      ${lib.getExe pkgs.bash} -c '[[ ":$XDG_CURRENT_DESKTOP:" == *:niri:* ]]'
    '';

    # Stop DMS from re-imposing its own display layout over the Nix-pinned niri
    # outputs
    xdg.configFile."DankMaterialShell/monitors.json".text = builtins.toJSON {
      version = 1;
      configurations = [ ];
    };

    # Seed DMS's settings.json from Nix once, then let DMS own it at runtime so
    # GUI changes persist across reboots — specifically desktop-widget positions,
    # which DMS only stores here (no separate state file) and rewrites on drag.
    #
    # We deliberately do NOT use programs.dank-material-shell.settings: that
    # writes a read-only store symlink, so every DMS write fails with EACCES and
    # the layout reverts to the snapshot on each restart. Instead ./settings.json
    # (+ the dmsSettings scalars) is a *baseline* copied into a writable file on
    # first activation only.
    #
    # The guard seeds when the target is missing or still the old store symlink;
    # once it's a plain writable file, DMS owns it and activation leaves it alone
    # (home-manager's cleanup only removes paths that still link into the store,
    # so the writable copy is never reaped). To re-baseline from Nix after
    # editing ./settings.json, delete the file and re-activate:
    #   rm ~/.config/DankMaterialShell/settings.json && home-manager switch
    home.activation.seedDmsSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${dmsSettingsPath}" ] || [ -L "${dmsSettingsPath}" ]; then
        run rm -f ${lib.escapeShellArg dmsSettingsPath}
        run mkdir -p "$(dirname ${lib.escapeShellArg dmsSettingsPath})"
        run install -m 0644 ${dmsSettingsSeed} ${lib.escapeShellArg dmsSettingsPath}
      fi
    '';

    # qt6ct.conf: Nix-owned, written unconditionally each activation (the style /
    # palette / icon theme are fully declarative). Must be a writable copy, not a
    # store symlink — the qt6ct-reload service touches it and qt6ct rewrites it on
    # reload. The matugen palette it points at is regenerated by DMS at runtime.
    home.activation.seedQt6ctConf = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run rm -f ${lib.escapeShellArg qt6ctConfPath}
      run install -Dm0644 ${qt6ctConf} ${lib.escapeShellArg qt6ctConfPath}
    '';

    # Keep the DMS dock's pinned apps (session.json `pinnedApps`) declarative and
    # host-overridable via the `dockApps` option above. session.json is otherwise
    # DMS-owned runtime state (DMS rewrites it on launcher use, wallpaper change,
    # …), so we can't symlink it — we patch just the one key with jq, preserving
    # everything else, and only when it actually differs. A running DMS holds the
    # session in memory and would clobber our write on its next save, so restart
    # it when the value changes (best-effort; at boot DMS just reads the file).
    home.activation.dmsDockApps = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      session=${lib.escapeShellArg dmsSessionPath}
      desired=${lib.escapeShellArg (builtins.toJSON cfg.dockApps)}
      run mkdir -p "$(dirname "$session")"
      if [ -f "$session" ]; then
        current=$(${pkgs.jq}/bin/jq -c '.pinnedApps // null' "$session")
      else
        current=missing
        run sh -c "echo '{}' > $session"
      fi
      if [ "$current" != "$(printf '%s' "$desired" | ${pkgs.jq}/bin/jq -c .)" ]; then
        tmp=$(mktemp)
        ${pkgs.jq}/bin/jq --argjson apps "$desired" '.pinnedApps = $apps' "$session" > "$tmp" \
          && run mv "$tmp" "$session"
        ${pkgs.systemd}/bin/systemctl --user restart dms.service 2>/dev/null || true
      fi
    '';

    # Weather location: drive DMS's weather off dafos.user.location rather than
    # its IP-based auto location. 
    home.activation.dmsWeather = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      session=${lib.escapeShellArg dmsSessionPath}
      coords=${lib.escapeShellArg "${userLocation.latitude},${userLocation.longitude}"}
      name=${lib.escapeShellArg userLocation.name}
      run mkdir -p "$(dirname "$session")"
      [ -f "$session" ] || run sh -c "echo '{}' > $session"
      cur_coords=$(${pkgs.jq}/bin/jq -r '.weatherCoordinates // ""' "$session")
      cur_name=$(${pkgs.jq}/bin/jq -r '.weatherLocation // ""' "$session")
      if [ "$cur_coords" != "$coords" ] || [ "$cur_name" != "$name" ]; then
        tmp=$(mktemp)
        ${pkgs.jq}/bin/jq --arg c "$coords" --arg n "$name" \
          '.weatherCoordinates = $c | .weatherLocation = $n' "$session" > "$tmp" \
          && run mv "$tmp" "$session"
        ${pkgs.systemd}/bin/systemctl --user restart dms.service 2>/dev/null || true
      fi
    '';

    programs.dank-material-shell = {
      enable = true;

      # Plugin sources, pinned in ./plugins.nix (symlinked into the plugins dir).
      # Enable-state/settings stay in DMS's runtime-owned plugin_settings.json.
      plugins = import ./plugins.nix { inherit pkgs; };

      systemd = {
        enable = true; # Systemd service for auto-start
        restartIfChanged = true; # Auto-restart dms.service when dankMaterialShell changes
      };

      niri = {
        # Keybinds are defined directly in the niri module
        enableKeybinds = false;

        includes.filesToInclude = [
          "alttab"
          "binds"
          "colors"
          "cursor"
          "layout"
          "windowrules"
          "wpblur"
        ];
      };

      # Core features
      enableSystemMonitoring = true; # System monitoring widgets (dgop)
      enableVPN = true; # VPN management widget
      enableDynamicTheming = true; # Wallpaper-based theming (matugen)
      enableAudioWavelength = true; # Audio visualizer (cava)
      enableCalendarEvents = true; # Calendar integration (khal)
    };
  };
}
