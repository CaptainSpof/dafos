{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    mkIf
    types
    ;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.services.media-export;

  clients = cfg.lanClients ++ cfg.tailnetClients;
  exportOptions = "ro,no_subtree_check,root_squash";
in
{
  options.${namespace}.services.media-export = {
    enable = mkBoolOpt false "Whether or not to export the media pool read-only over NFSv4.";

    path = mkOpt types.str "/mnt/data" "Directory to export; must be a mount point.";

    lanClients = mkOpt (types.listOf types.str) [ ] ''
      LAN addresses allowed to mount the export. Each also gets a firewall rule
      for TCP 2049 scoped to that source address; nothing else on the LAN can
      reach the port. Needs a stable address (a DHCP reservation on the router).
    '';

    tailnetClients = mkOpt (types.listOf types.str) [ ] ''
      Tailscale addresses allowed to mount the export. No firewall rule is
      needed: tailscale0 is a trusted interface on this host.
    '';
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = clients != [ ];
        message = "${namespace}.services.media-export needs at least one client.";
      }
    ];

    services.nfs = {
      server = {
        enable = true;
        exports = ''
          ${cfg.path} ${concatStringsSep " " (map (c: "${c}(${exportOptions})") clients)}
        '';
      };
      # NFSv4 only: a single TCP port (2049), no rpcbind/mountd exposure.
      settings.nfsd = {
        udp = false;
        vers3 = false;
      };
    };

    # The export lives on the USB media disk. An exported empty directory on the
    # NVMe root would hand clients nothing, and would stay stale after the disk
    # returns, so the server is tied to the mount in both directions: it needs
    # the mount, and starting the mount starts it. (Requires= alone propagates a
    # stop but not a start.)
    systemd.services.nfs-server = {
      unitConfig.RequiresMountsFor = cfg.path;
      wantedBy = lib.mkForce [ "mnt-data.mount" ];
    };

    networking.firewall = {
      extraCommands = concatMapStringsSep "\n" (
        c: "iptables -A nixos-fw -p tcp -s ${c} --dport 2049 -j nixos-fw-accept"
      ) cfg.lanClients;
      extraStopCommands = concatMapStringsSep "\n" (
        c: "iptables -D nixos-fw -p tcp -s ${c} --dport 2049 -j nixos-fw-accept || true"
      ) cfg.lanClients;
    };
  };
}
