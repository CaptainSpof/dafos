{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.moondeck-buddy;

  inherit (lib)
    mkEnableOption
    mkIf
    getExe
    types
    ;
  inherit (lib.${namespace}) mkOpt;
in
{
  options.${namespace}.services.moondeck-buddy = {
    enable = mkEnableOption "Whether or not to enable MoonDeck Buddy (host companion for the MoonDeck Steam Deck plugin).";
    port = mkOpt types.port 59999 "Port Buddy listens on; the MoonDeck plugin's default expects 59999.";
  };

  config = mkIf cfg.enable {
    # MoonDeckStream must also be reachable for Sunshine's app list, so ship
    # the whole package system-wide rather than only wiring the service.
    environment.systemPackages = [ pkgs.${namespace}.moondeck-buddy ];

    # The MoonDeck plugin on the Deck talks to Buddy directly over the LAN.
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Upstream's --enable-autostart generates a headless service plus a helper
    # that flips GUI mode on DE login — that dance exists for SteamOS's
    # desktop/gamemode switching. Here the box always has a graphical session,
    # so one user service in tray mode is enough.
    systemd.user.services.moondeck-buddy = {
      description = "MoonDeck host companion";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      environment.NO_GUI = "false";
      serviceConfig = {
        ExecStart = getExe pkgs.${namespace}.moondeck-buddy;
        Restart = "on-failure";
        RestartSec = 10;
        # Buddy exits with 143 on SIGTERM (matches upstream's unit).
        SuccessExitStatus = 143;
      };
    };
  };
}
