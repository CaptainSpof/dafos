# OpenThread border router for dafoltop's Home Assistant, next to the Matter
# server on dafpi (Thread needs IPv6, which dafoltop has none of; see
# matter-server.nix). The radio is the SONOFF ZBDongle-E (EFR32MG21) freed by
# the ZHA → Zigbee2MQTT migration, reflashed with OpenThread RCP firmware.
#
# HA's OTBR integration talks to the REST API; it is open to `clients` only,
# since whoever reaches it controls the Thread network.
_: {
  flake.modules.nixos.openthread-border-router =
    { config, lib, ... }:

    let
      inherit (lib)
        concatMapStrings
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.dafos.services.openthread-border-router;
      otbr = config.services.openthread-border-router;
    in
    {
      options.dafos.services.openthread-border-router = {
        enable = mkEnableOption "the OpenThread border router for Home Assistant";

        device = mkOption {
          type = types.path;
          description = "The RCP radio's /dev/serial/by-id path.";
        };

        baudRate = mkOption {
          type = types.ints.positive;
          default = 460800;
          description = "The RCP firmware's UART baud rate (NabuCasa's ZBDongle-E builds use 460800).";
        };

        interface = mkOption {
          type = types.str;
          description = "The LAN interface the Thread mesh prefix is advertised on.";
        };

        clients = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "IPv4 addresses allowed to the REST API (Home Assistant).";
        };
      };

      config = mkIf cfg.enable {
        services.openthread-border-router = {
          enable = true;
          backboneInterfaces = [ cfg.interface ];
          rest.listenAddress = "0.0.0.0";
          radio = {
            inherit (cfg) device baudRate;
          };
        };

        networking.firewall.extraCommands = concatMapStrings (ip: ''
          iptables -w -A nixos-fw -p tcp -s ${ip} --dport ${toString otbr.rest.listenPort} -j nixos-fw-accept
        '') cfg.clients;
      };
    };
}
