{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf getExe';
  inherit (lib.${namespace}) mkBoolOpt;
  inherit (config.${namespace}.user.location) latitude longitude;

  cfg = config.${namespace}.services.koi;
in
{
  options.${namespace}.services.koi = {
    enable = mkBoolOpt false "Whether or not to enable koi.";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.kdePackages.koi
    ];

    systemd.user.services.koi = {
      Unit = {
        Description = "koi";
        # koi is a Plasma color-scheme switcher; bind it to the Plasma
        # session only. Pulling it in via multi-user.target started it at
        # boot before any display existed, so it fell back to the Qt xcb
        # plugin, aborted, and crash-looped under non-Plasma sessions (niri).
        After = [ "plasma-workspace.target" ];
        PartOf = [ "plasma-workspace.target" ];
      };

      Install = {
        WantedBy = [ "plasma-workspace.target" ];
      };

      Service = {
        ExecStart = "${getExe' pkgs.kdePackages.koi "koi"}";
        Restart = "on-failure";
      };
    };

    xdg.configFile."koirc".text = lib.generators.toINI { } {
      General = {
        notify = 2;
        schedule = 2;
        schedule-type = "sun";
        inherit latitude longitude;
        start-hidden = 2;
      };
      ColorScheme = {
        enabled = true;
        dark = "${pkgs.kde-gruvbox}/share/color-schemes/Gruvbox.colors";
        light = "${pkgs.dafos.kde-warm-eyes}/share/color-schemes/WarmEyes.colors";
      };
      GTKTheme = {
        enabled = true;
        dark = "Gruvbox-Dark";
        light = "Gruvbox-Light";
      };
      IconTheme = {
        enabled = false;
        dark = "Papirus-Dark";
        light = "Papirus";
      };
    };
  };
}
