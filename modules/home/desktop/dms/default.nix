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

  # DMS's built-in qt6ct matugen template writes this palette file on each theme
  # change; our qt6ct.conf (style=Darkly) points its color_scheme_path at it.
  targetOutputPath = "${config.xdg.configHome}/qt6ct/colors/matugen.conf";

  # GTK matugen template and its rendered outputs. matugen writes
  # ~/.config/gtk-{3,4}.0/gtk.css on each theme change so GTK/libadwaita apps
  # follow the wallpaper under niri. (qt6ct and wezterm are handled by DMS's own
  # built-in templates now; only GTK is still hand-rolled here.)
  gtkTemplatePath = "${matugenConfigDir}/templates/gtk-colors.css";
  gtk3CssPath = "${config.xdg.configHome}/gtk-3.0/gtk.css";
  gtk4CssPath = "${config.xdg.configHome}/gtk-4.0/gtk.css";

  qt6ctConfPath = "${config.xdg.configHome}/qt6ct/qt6ct.conf";
  qt6ctConf = pkgs.writeText "qt6ct.conf" ''
    [Appearance]
    style=Darkly
    custom_palette=true
    color_scheme_path=${targetOutputPath}
    icon_theme=Papirus-Dark
  '';

  cfg = config.${namespace}.desktop.dms;

  quickshellWithWebSockets = pkgs.symlinkJoin {
    name = "quickshell-with-qtwebsockets";
    paths = [ pkgs.quickshell ];
    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    postBuild = ''
      for b in quickshell qs; do
        wrapProgram "$out/bin/$b" \
          --prefix NIXPKGS_QT6_QML_IMPORT_PATH : ${pkgs.kdePackages.qtwebsockets}/lib/qt-6/qml
      done
    '';
  };

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
    # DMS's built-in per-app matugen templates default ON (runDmsMatugenTemplates
    # + matugenTemplate*). We let DMS own the qt6ct and wezterm palettes — its
    # built-ins write the same files we used to (qt6ct/colors/matugen.conf,
    # wezterm/colors/dank-theme.toml) and it self-touches qt6ct.conf to trigger
    # reloads. Only GTK is still hand-rolled (see gtk-colors.css below), so
    # disable just that one to avoid a redundant second write; everything else
    # (vesktop/vencord dank-discord.css, etc.) stays on.
    matugenTemplateGtk = false;
    # Don't let DMS follow the xdg portal's appearance signal: the kde Settings
    # backend always reports "light" under Niri, which would drag DMS back to
    # light on every change. DMS owns light/dark directly (theme dark/light).
    syncModeWithPortal = false;
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

    # GTK colours, matugen-rendered. libadwaita reads ~/.config/gtk-4.0/gtk.css
    # directly; adw-gtk3 picks the same @define-color names up for GTK3. matugen
    # overwrites these on each theme change (DMS triggers it under niri).
    xdg.configFile."matugen/templates/gtk-colors.css".text = ''
      /* Generated by matugen — dynamic GTK colours (niri/DMS). */
      @define-color accent_color {{colors.primary.default.hex}};
      @define-color accent_bg_color {{colors.primary.default.hex}};
      @define-color accent_fg_color {{colors.on_primary.default.hex}};

      @define-color window_bg_color {{colors.surface.default.hex}};
      @define-color window_fg_color {{colors.on_surface.default.hex}};

      @define-color view_bg_color {{colors.surface.default.hex}};
      @define-color view_fg_color {{colors.on_surface.default.hex}};

      @define-color headerbar_bg_color {{colors.surface_container.default.hex}};
      @define-color headerbar_fg_color {{colors.on_surface.default.hex}};
      @define-color headerbar_border_color {{colors.on_surface.default.hex}};
      @define-color headerbar_backdrop_color {{colors.surface.default.hex}};
      @define-color headerbar_shade_color {{colors.shadow.default.hex}};

      @define-color card_bg_color {{colors.surface_container.default.hex}};
      @define-color card_fg_color {{colors.on_surface.default.hex}};
      @define-color card_shade_color {{colors.shadow.default.hex}};

      @define-color dialog_bg_color {{colors.surface_container_high.default.hex}};
      @define-color dialog_fg_color {{colors.on_surface.default.hex}};

      @define-color popover_bg_color {{colors.surface_container.default.hex}};
      @define-color popover_fg_color {{colors.on_surface.default.hex}};

      @define-color sidebar_bg_color {{colors.surface_container.default.hex}};
      @define-color sidebar_fg_color {{colors.on_surface.default.hex}};
      @define-color sidebar_backdrop_color {{colors.surface.default.hex}};
      @define-color sidebar_border_color {{colors.outline_variant.default.hex}};
      @define-color sidebar_shade_color {{colors.shadow.default.hex}};

      @define-color secondary_sidebar_bg_color {{colors.surface_container_low.default.hex}};
      @define-color secondary_sidebar_fg_color {{colors.on_surface.default.hex}};

      @define-color destructive_color {{colors.error.default.hex}};
      @define-color destructive_bg_color {{colors.error.default.hex}};
      @define-color destructive_fg_color {{colors.on_error.default.hex}};

      @define-color success_color {{colors.tertiary.default.hex}};
      @define-color success_bg_color {{colors.tertiary.default.hex}};
      @define-color success_fg_color {{colors.on_tertiary.default.hex}};

      @define-color warning_color {{colors.secondary.default.hex}};
      @define-color warning_bg_color {{colors.secondary.default.hex}};
      @define-color warning_fg_color {{colors.on_secondary.default.hex}};

      @define-color error_color {{colors.error.default.hex}};
      @define-color error_bg_color {{colors.error.default.hex}};
      @define-color error_fg_color {{colors.on_error.default.hex}};

      @define-color borders {{colors.outline_variant.default.hex}};
    '';

    xdg.configFile."matugen/config.toml".text = lib.mkForce ''
      [config]
      # General Matugen settings can go here
      # (qt6ct + wezterm are handled by DMS's own built-in templates; only the
      # GTK templates below are ours.)

      [templates.gtk3]
      input_path = "${gtkTemplatePath}"
      output_path = "${gtk3CssPath}"

      [templates.gtk4]
      input_path = "${gtkTemplatePath}"
      output_path = "${gtk4CssPath}"
    '';

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
    # icon theme are fully declarative). Must be a writable copy, not a store
    # symlink — DMS touches it (refreshQt6ct) on each theme change and qt6ct
    # rewrites it on reload. The matugen palette it points at (color_scheme_path)
    # is regenerated by DMS's built-in qt6ct template at runtime.
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

      # Quickshell wrapped with the QtWebSockets QML module (see let binding) so
      # the Home Assistant plugin can `import QtWebSockets`.
      quickshell.package = quickshellWithWebSockets;

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
