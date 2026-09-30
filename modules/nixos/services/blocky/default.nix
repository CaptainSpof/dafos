{
  lib,
  config,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStrings
    mapAttrsToList
    mkEnableOption
    mkIf
    types
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.blocky;

  # blocky binds `hostAddress` itself, and that address comes from DHCP a moment
  # after the unit would otherwise start.
  waitForAddress = pkgs.writeShellScript "blocky-wait-for-address" ''
    until ${pkgs.iproute2}/bin/ip -4 -o addr show to ${cfg.hostAddress} | ${pkgs.gnugrep}/bin/grep -q .; do
      sleep 0.5
    done
  '';
in
{
  options.${namespace}.services.blocky = {
    enable = mkEnableOption "Whether or not to configure blocky.";

    hostAddress = mkOpt types.str "" ''
      LAN address blocky binds :53 on, and the address `domain` resolves to.
      Must be set: binding 0.0.0.0 collides with systemd-resolved's stub listener.
    '';

    domain = mkOpt types.str "daftdaf.dev" "Domain resolved locally to hostAddress.";

    externalSubdomains = mkOpt (types.attrsOf types.str) {
      blog = "captainspof.github.io";
    } "Subdomains of `domain` hosted elsewhere, as `name = cname-target`; exempt from the LAN mapping.";

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

        # Subdomains hosted off-box would otherwise be swallowed by the mapping
        # above. blocky checks the exact name before its parents, so a CNAME
        # here wins and its target is resolved upstream as usual. `mapping`
        # only takes IPs; CNAMEs need a zone.
        customDNS.zone = concatStrings (
          mapAttrsToList (
            name: target: "${name}.${cfg.domain}. 3600 CNAME ${target}.\n"
          ) cfg.externalSubdomains
        );

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

    # `Wants=network-online.target` is not enough here: NetworkManager-wait-online
    # is masked on dafoltop, so nothing waits for the lease. Booting without it,
    # blocky failed to bind 4 times in under a second; the default start limit is
    # 5 in 10 s, so one more and DNS for the LAN stays down until someone notices.
    # Wait for the address instead, and keep retrying instead of giving up.
    systemd.services.blocky = {
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        ExecStartPre = "${waitForAddress}";
        RestartSec = "2s";
      };
    };
  };
}
