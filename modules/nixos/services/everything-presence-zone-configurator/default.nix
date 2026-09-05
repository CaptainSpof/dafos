{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    types
    optionals
    getExe
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.everything-presence-zone-configurator;

  name = "everything-presence-zone-configurator";

  useOwnSecret = cfg.tokenFile == null;
  tokenPath =
    if useOwnSecret then config.sops.secrets."zone-configurator-ha-token".path else cfg.tokenFile;
in
{
  options.${namespace}.services.everything-presence-zone-configurator = {
    enable = mkEnableOption "the Everything Presence Zone Configurator";

    port = mkOpt types.port 42069 "Port the zone configurator web UI listens on.";

    openFirewall = mkBoolOpt true "Whether to open `port` to the LAN.";

    homeAssistantUrl =
      mkOpt types.str "http://127.0.0.1:8123"
        "Base URL of the Home Assistant instance to talk to.";

    tokenFile = mkOpt (types.nullOr types.path) null ''
      File holding a Home Assistant long-lived access token. Defaults to the
      `zone-configurator-ha-token` entry of
      `secrets/daf/everything-presence.yaml`. Read by systemd as root and
      handed to the service through a credential, so it never needs to be
      readable by the service user.
    '';

    firmware = {
      lanPort = mkOpt types.port 38080 ''
        Port of the LAN HTTP server the configurator uses to hand firmware
        images to ESPHome devices during an OTA update.
      '';

      openFirewall = mkBoolOpt true "Whether to open `firmware.lanPort` to the LAN.";

      lanIp = mkOpt (types.nullOr types.str) null ''
        Address to advertise to devices for OTA downloads. Worth setting on a
        host with podman bridges or tailscale: upstream auto-detection only
        skips docker/br-/veth/tun/wg interfaces, so it can pick 10.89.x.x or
        a 100.64/10 tailnet address that the sensors cannot reach.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Upstream only ships this as a Supervisor add-on or a Docker image; on a
    # host running home-assistant natively it is just a node service, so it runs
    # as one (package: `packages/everything-presence-zone-configurator`).
    sops.secrets = mkIf useOwnSecret {
      "zone-configurator-ha-token".sopsFile =
        lib.snowfall.fs.get-file "secrets/daf/everything-presence.yaml";
    };

    systemd.services.${name} = {
      description = "Everything Presence Zone Configurator";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "home-assistant.service"
      ];

      environment = {
        NODE_ENV = "production";
        PORT = toString cfg.port;
        HA_BASE_URL = cfg.homeAssistantUrl;
        # systemd expands %d to the per-unit credentials directory.
        HA_LONG_LIVED_TOKEN_FILE = "%d/ha-token";
        DATA_DIR = "/var/lib/${name}";
        FIRMWARE_LAN_PORT = toString cfg.firmware.lanPort;
      }
      // lib.optionalAttrs (cfg.firmware.lanIp != null) {
        FIRMWARE_LAN_IP = cfg.firmware.lanIp;
      };

      serviceConfig = {
        ExecStart = getExe pkgs.${namespace}.everything-presence-zone-configurator;
        LoadCredential = [ "ha-token:${tokenPath}" ];

        DynamicUser = true;
        StateDirectory = name;

        # The backend exits (rather than retrying) when Home Assistant is
        # unreachable at startup, so a restart loop *is* the reconnect strategy —
        # slow enough not to spin during a home-assistant restart.
        Restart = "always";
        RestartSec = 30;

        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };
    };

    networking.firewall.allowedTCPPorts =
      optionals cfg.openFirewall [ cfg.port ]
      ++ optionals cfg.firmware.openFirewall [ cfg.firmware.lanPort ];
  };
}
