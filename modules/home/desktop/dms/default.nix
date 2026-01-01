{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  # Define paths relative to the user's home directory for clarity
  matugenConfigDir = "${config.xdg.configHome}/matugen";
  templatePath = "${matugenConfigDir}/templates/qtct-colors.conf";

  targetOutputPath = "${config.xdg.configHome}/qt6ct/colors/matugen.conf";

  cfg = config.${namespace}.desktop.dms;
in
{
  options.${namespace}.desktop.dms = {
    enable = mkBoolOpt true "Whether or not to use dms";
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
      # The fix: PathModified must be inside the 'Path' set
      Path = {
        PathModified = "%h/.config/qt6ct/colors/matugen.conf";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    programs.dank-material-shell = {
      enable = true;

      systemd = {
        enable = true; # Systemd service for auto-start
        restartIfChanged = true; # Auto-restart dms.service when dankMaterialShell changes
      };

      niri = {
        enableKeybinds = true; # Automatic keybinding configuration
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
