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

      # The OTA provider the server spawns to push firmware updates to devices.
      # Upstream's container image downloads this prebuilt CHIP example from
      # home-assistant-libs (see python-matter-server's Dockerfile); nixpkgs
      # does not package it, so update/install failed with "No such file or
      # directory: 'chip-ota-provider-app'" (2026-10-22).
      otaProvider =
        let
          arch =
            {
              aarch64-linux = {
                name = "aarch64";
                hash = "sha256-4GirbEBQ4j6qbM2pv37M3Et5KiUU4QmMvBK0FM1kqn4=";
              };
              x86_64-linux = {
                name = "x86-64";
                hash = "sha256-RVDfevZSnkYgRj0cASf4MOwkBMgXrUxjQ7KeMs7AFE4=";
              };
            }
            .${pkgs.stdenv.hostPlatform.system};
        in
        pkgs.stdenv.mkDerivation rec {
          pname = "chip-ota-provider-app";
          version = "2025.9.0";
          src = pkgs.fetchurl {
            url = "https://github.com/home-assistant-libs/matter-linux-ota-provider/releases/download/${version}/chip-ota-provider-app-${arch.name}";
            inherit (arch) hash;
          };
          dontUnpack = true;
          nativeBuildInputs = [ pkgs.autoPatchelfHook ];
          buildInputs = [
            pkgs.libnl
            pkgs.stdenv.cc.cc.lib
          ];
          installPhase = "install -Dm755 $src $out/bin/chip-ota-provider-app";
          meta.mainProgram = "chip-ota-provider-app";
        };
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

        # The server runs it from PATH
        systemd.services.matter-server.path = [ otaProvider ];

        # Matter's operational port, for the devices on the LAN (IPv4 and IPv6).
        networking.firewall.allowedUDPPorts = [ 5540 ];

        # The OTA provider listens on a random port (`--secured-device-port 0`)
        # that a Thread device must reach to fetch its image; Thread traffic
        # arrives on the border router's interface.
        networking.firewall.interfaces = mkIf config.services.openthread-border-router.enable {
          ${config.services.openthread-border-router.interfaceName}.allowedUDPPortRanges = [
            {
              from = 1024;
              to = 65535;
            }
          ];
        };

        # The websocket: Home Assistant only.
        networking.firewall.extraCommands = concatMapStrings (ip: ''
          iptables -w -A nixos-fw -p tcp -s ${ip} --dport ${toString config.services.matter-server.port} -j nixos-fw-accept
        '') cfg.clients;
      };
    };
}
