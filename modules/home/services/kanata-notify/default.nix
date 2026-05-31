{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib)
    mkIf
    getExe
    getExe'
    types
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.kanata-notify;

  notifier =
    pkgs.writers.writePython3Bin "kanata-layer-notify" { flakeIgnore = [ "E501" ]; }
      (builtins.readFile ./kanata-layer-notify.py);
in
{
  options.${namespace}.services.kanata-notify = {
    enable = mkBoolOpt false "Send a desktop notification on kanata persistent-layer changes.";
    port = mkOpt types.port 5829 "Port of kanata's TCP server to connect to (must match system.kanata.tcpPort).";
  };

  config = mkIf cfg.enable {
    systemd.user.services.kanata-notify = {
      Unit = {
        Description = "Desktop notifications for kanata layer changes";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Install.WantedBy = [ "graphical-session.target" ];

      Service = {
        ExecStart = getExe notifier;
        Environment = [
          "KANATA_PORT=${toString cfg.port}"
          "NOTIFY_SEND=${getExe' pkgs.libnotify "notify-send"}"
        ];
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
