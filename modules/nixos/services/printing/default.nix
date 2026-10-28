{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.services.printing;
in
{
  options.${namespace}.services.printing = {
    enable = mkBoolOpt false "Whether or not to configure printing support.";
  };

  config = mkIf cfg.enable {
    services.printing = {
      enable = true;
      browsing = true;

      drivers = [
        pkgs.cnijfilter2
      ];
    };

    # cups-browsed's auto-created implicitclass queue keeps pausing itself when
    # the printer reconnects, stranding jobs; a fixed IPP Everywhere queue
    # talks to it directly. Not hardware.printers: it runs lpadmin in cups'
    # postStart, and `-m everywhere` must reach the printer, so a powered-off
    # printer would fail cups itself. The queue persists in /var/lib/cups, so
    # this only has to succeed once.
    systemd.services.ensure-canon-printer = {
      description = "Create the fixed Canon TS9100 CUPS queue";
      wants = [
        "cups.service"
        "network-online.target"
      ];
      after = [
        "cups.service"
        "network-online.target"
        "avahi-daemon.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [ config.services.printing.package ];
      script = ''
        lpstat -p Canon_TS9100 >/dev/null 2>&1 && exit 0
        lpadmin -p Canon_TS9100 -D "Canon TS9100" -E \
          -v ipp://DFC76A000000.local/ipp/print -m everywhere
        lpadmin -d Canon_TS9100
      '';
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "5min";
      };
      unitConfig.StartLimitIntervalSec = 0;
    };

    environment.systemPackages = with pkgs.kdePackages; [ skanpage ];
  };
}
