# LAN DNS: ad-blocking resolver that also answers the public domain with a
# LAN address, so clients reach Traefik directly instead of hairpinning
# through the Freebox. dafoltop is the primary, dafpi the secondary.
{
  flake.modules.nixos.blocky =
    {
      lib,
      config,
      pkgs,
      ...
    }:

    let
      inherit (lib)
        concatStrings
        mapAttrsToList
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.dafos.services.blocky;

      # blocky binds `hostAddress` itself, and that address comes from DHCP a moment
      # after the unit would otherwise start. Run by its own oneshot unit, see below.
      waitForAddress = pkgs.writeShellScript "blocky-wait-for-address" ''
        until ${pkgs.iproute2}/bin/ip -4 -o addr show to ${cfg.hostAddress} | ${pkgs.gnugrep}/bin/grep -q .; do
          sleep 0.5
        done
      '';
    in
    {
      options.dafos.services.blocky = {
        enable = mkEnableOption "Whether or not to configure blocky.";

        hostAddress = mkOption {
          type = types.str;
          default = "";
          description = ''
            LAN address blocky binds :53 on.
            Must be set: binding 0.0.0.0 collides with systemd-resolved's stub listener.
          '';
        };

        domainAddress = mkOption {
          type = types.str;
          default = cfg.hostAddress;
          defaultText = lib.literalExpression "config.dafos.services.blocky.hostAddress";
          description = ''
            LAN address `domain` and its subdomains resolve to: the host running
            Traefik. A secondary resolver on another host points it there.
          '';
        };

        domain = mkOption {
          type = types.str;
          default = "daftdaf.dev";
          description = "Domain resolved locally to domainAddress.";
        };

        externalSubdomains = mkOption {
          type = types.attrsOf types.str;
          default = {
            blog = "captainspof.github.io";
          };
          description = "Subdomains of `domain` hosted elsewhere, as `name = cname-target`; exempt from the LAN mapping.";
        };

        upstreams = mkOption {
          type = types.listOf types.str;
          default = [
            "tcp-tls:1.1.1.1:853"
            "tcp-tls:1.0.0.1:853"
          ];
          description = "Upstream resolvers, DNS-over-TLS by IP so no bootstrap resolver is needed.";
        };

        denylists = mkOption {
          type = types.listOf types.str;
          default = [
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
          ];
          description = "Blocklist sources.";
        };

        openFirewall = mkOption {
          type = types.bool;
          default = true;
          description = "Open 53/tcp and 53/udp.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.hostAddress != "";
            message = "dafos.services.blocky.hostAddress must be set to this host's LAN address.";
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

            # Resolve the public domain to the Traefik host so LAN clients reach
            # it directly instead of hairpinning out through the Freebox.
            # Subdomains are covered by the zone entry.
            customDNS.mapping.${cfg.domain} = cfg.domainAddress;

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
        #
        # The wait is its own oneshot, not an ExecStartPre: blocky runs with
        # RestrictAddressFamilies=AF_INET AF_INET6, so `ip` cannot open its netlink
        # socket inside the unit and the wait never finishes. The first version of
        # this did exactly that and took DNS down after the switch. `Wants`, not
        # `Requires`: if the address never shows up the wait times out and blocky is
        # still started, then retries every 2 s instead of never starting.
        systemd.services.blocky-wait-for-address = {
          description = "Wait for ${cfg.hostAddress} to exist before blocky binds it";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${waitForAddress}";
            TimeoutStartSec = "60s";
          };
        };

        systemd.services.blocky = {
          wants = [ "blocky-wait-for-address.service" ];
          after = [ "blocky-wait-for-address.service" ];
          unitConfig.StartLimitIntervalSec = 0;
          serviceConfig.RestartSec = "2s";
        };
      };
    };
}
