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
        After = [
          "plasma-workspace.target"
          "multi-user.target"
        ];
      };

      Install = {
        WantedBy = [
          "plasma-workspace.target"
          "multi-user.target"
        ];
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
