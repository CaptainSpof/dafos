{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

with lib;
with lib.${namespace};
let
  inherit (lib) mkIf getExe;
  inherit (lib.${namespace}) mkBoolOpt;
  inherit (config.${namespace}) user;
  inherit (config.users.users.${user.name}) home;

  cfg = config.${namespace}.desktop.addons.kanshi;
in
{
  options.${namespace}.desktop.addons.kanshi = {
    enable = mkBoolOpt false "Whether to enable Kanshi in the desktop environment.";
  };

  config = mkIf cfg.enable {
    dafos.home.configFile."kanshi/config".source = ./config;

    environment.systemPackages = with pkgs; [ kanshi ];

    # configuring kanshi
    systemd.user.services.kanshi = {
      description = "Kanshi output autoconfig ";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      environment = {
        XDG_CONFIG_HOME = "${home}/.config";
      };
      serviceConfig = {
        ExecCondition = ''
          ${getExe pkgs.bash} -c '[ -n "$WAYLAND_DISPLAY" ]'
        '';

        ExecStart = ''
          ${getExe pkgs.kanshi}
        '';

        RestartSec = 5;
        Restart = "always";
      };
    };
  };
}
