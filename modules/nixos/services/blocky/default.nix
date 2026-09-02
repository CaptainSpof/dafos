{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.blocky;
in
{
  options.${namespace}.services.blocky = {
    enable = mkEnableOption "Whether or not to configure blocky.";

    hostAddress = mkOpt types.str "" ''
      LAN address blocky binds :53 on, and the address `domain` resolves to.
      Must be set: binding 0.0.0.0 collides with systemd-resolved's stub listener.
    '';

    domain = mkOpt types.str "daftdaf.dev" "Domain resolved locally to hostAddress.";

    upstreams = mkOpt (types.listOf types.str) [
      "tcp-tls:1.1.1.1:853"
      "tcp-tls:1.0.0.1:853"
    ] "Upstream resolvers, DNS-over-TLS by IP so no bootstrap resolver is needed.";

    denylists = mkOpt (types.listOf types.str) [
      "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    ] "Blocklist sources.";

    openFirewall = mkBoolOpt true "Open 53/tcp and 53/udp.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.hostAddress != "";
        message = "${namespace}.services.blocky.hostAddress must be set to this host's LAN address.";
      }
    ];

    services.blocky = {
      enable = true;

      settings = {
        ports = {
          dns = "${cfg.hostAddress}:53";
          http = "${cfg.hostAddress}:4000";
        };

        upstreams.groups.default = cfg.upstreams;

        # Resolve the public domain to this host so LAN clients reach Traefik
        # directly instead of hairpinning out through the Freebox. Subdomains
        # are covered by the zone entry.
        customDNS.mapping.${cfg.domain} = cfg.hostAddress;

        blocking = {
          denylists.ads = cfg.denylists;
          clientGroupsBlock.default = [ "ads" ];
        };

        caching = {
          minTime = "5m";
          maxTime = "30m";
          prefetching = true;
        };

        log.level = "info";
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
  };
}
