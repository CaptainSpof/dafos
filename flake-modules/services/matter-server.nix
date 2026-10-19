# Matter controller (python-matter-server) for dafoltop's Home Assistant.
#
# It runs on dafpi rather than next to HA because Matter (and Thread, which
# comes later through an OpenThread border router on the same box) needs IPv6,
# and dafoltop has none on purpose (see its AGENTS.md: qbittorrent's VPN-only
# egress, and an unfiltered firewall on any IPv6 link). HA's Matter
# integration reaches this server over the LAN websocket instead.
_: {
  flake.modules.nixos.matter-server =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      inherit (lib)
        concatMapStrings
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.dafos.services.matter-server;

      # At start the server downloads the Matter root certificates (DCL), and
      # one of them no longer parses with the current cryptography ("error
      # parsing asn1 value: ExtraData ... signature_alg"). The exception ended
      # the start task, so the websocket never opened (2026-10-19). Skip an
      # unreadable certificate instead.
      skipUnreadable = lib.concatStringsSep "\n" [
        "        try:"
        "            cert = x509.load_pem_x509_certificate(pem_certificate.encode())"
        "        except ValueError as err:"
        "            LOGGER.warning(\"Skipping unreadable certificate %s: %s\", subject, err)"
        "            return False"
      ];
      package = pkgs.python-matter-server.overridePythonAttrs (old: {
        # Fails under qemu's aarch64 emulation on dafbox (a socket option
        # it does not implement: "Protocol not available"), not on the Pi.
        disabledTests = (old.disabledTests or [ ]) ++ [ "test_server_start" ];
        postPatch = (old.postPatch or "") + ''
          substituteInPlace matter_server/server/helpers/paa_certificates.py \
            --replace-fail ${lib.escapeShellArg "        cert = x509.load_pem_x509_certificate(pem_certificate.encode())"} \
            ${lib.escapeShellArg skipUnreadable}
        '';
      });
    in
    {
      options.dafos.services.matter-server = {
        enable = mkEnableOption "the Matter controller for Home Assistant";

        interface = mkOption {
          type = types.str;
          description = "The LAN interface Matter devices are reached on (the server's primary interface; it would otherwise pick tailscale0 or a podman bridge).";
        };

        clients = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "IPv4 addresses allowed to the websocket (Home Assistant). Whoever reaches it controls every Matter device.";
        };
      };

      config = mkIf cfg.enable {
        services.matter-server = {
          enable = true;
          inherit package;
          extraArgs.primary-interface = cfg.interface;
        };

        # Matter's operational port, for the devices on the LAN (IPv4 and IPv6).
        networking.firewall.allowedUDPPorts = [ 5540 ];

        # The websocket: Home Assistant only.
        networking.firewall.extraCommands = concatMapStrings (ip: ''
          iptables -w -A nixos-fw -p tcp -s ${ip} --dport ${toString config.services.matter-server.port} -j nixos-fw-accept
        '') cfg.clients;
      };
    };
}
